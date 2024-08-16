param locationSite1 string
param locationSite2 string
param vmAdminUsername string
@secure()
param vmAdminPassword string
var useExisting = false
param enablediagnostics bool

/* ****************************** Cloud-Vnet ****************************** */

module defaultNSGSite1 '../modules/nsg.bicep' = {
  name: 'NetworkSecurityGroupSite1'
  params:{
    location: locationSite1
    name: 'nsg-site1'  
  }
}
resource cloud_vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'cloud-vnet'
  location: locationSite1
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: { id: defaultNSGSite1.outputs.nsgId }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

var cloudvpngwName = 'cloud-vpngw'
module cloudvpngateway '../modules/vpngw_act-act-APIPA.bicep' = {
  name: cloudvpngwName
  params: {
    location: locationSite1
    gatewayName: cloudvpngwName
    vnetName: cloud_vnet.name
    enablePrivateIpAddress: false
    bgpAsn: 65515
    bgpperingaddress: '10.0.1.4,10.0.1.5'
    customBgpIpAddress1: '169.254.21.1'
    customBgpIpAddress2: '169.254.22.1'
    useExisting: useExisting
    logAnalyticsId: logAnalytics.id
    enablediagnostics: enablediagnostics
  }
}

var lng01Name = 'lng-onp1'
resource lng_onp1 'Microsoft.Network/localNetworkGateways@2023-04-01' = {
  name: lng01Name
  location: locationSite1
  properties: {
    gatewayIpAddress: nva.outputs.publicIP
    bgpSettings:{
      asn: 65500
      bgpPeeringAddress: '169.254.99.1'
    }
  }
  dependsOn: [
    nva
  ]
}

resource conncetionCloudtoOnp1 'Microsoft.Network/connections@2023-04-01' = {
  name: 'fromCloudtoOnp1'
  location: locationSite1
  properties: {
    enableBgp: true
    virtualNetworkGateway1: {
      id: cloudvpngateway.outputs.vpngwId
      properties:{}
    }
    localNetworkGateway2: {
      id: lng_onp1.id
      properties:{}
    }
    connectionType: 'IPsec'
    connectionProtocol: 'IKEv2'
    routingWeight: 0
    sharedKey: 'TestPassw0rd!'
    ipsecPolicies:[
      {
        saLifeTimeSeconds: 3600
        saDataSizeKilobytes: 0
        ipsecEncryption: 'AES256'
        ipsecIntegrity: 'SHA1'
        ikeEncryption: 'AES256'
        ikeIntegrity: 'SHA256'
        dhGroup: 'DHGroup14'
        pfsGroup: 'None'
      }
    ]
    connectionMode: 'ResponderOnly'
    gatewayCustomBgpIpAddresses: [
      {
        ipConfigurationId: concat(resourceId('Microsoft.Network/virtualNetworkGateways', 'cloud-vpngw'), '/ipConfigurations/ipconfig1')
        customBgpIpAddress: '169.254.21.1'
      }
      {
        ipConfigurationId: concat(resourceId('Microsoft.Network/virtualNetworkGateways', 'cloud-vpngw'), '/ipConfigurations/ipconfig2')
        customBgpIpAddress: '169.254.22.1'
      }
    ]
  }
}


module cloudvm '../modules/ubuntu20.04.bicep' = {
  name: 'cloud-vm'
  params: {
    vmName: 'cloud-vm'
    VMadminUsername: vmAdminUsername
    VMadminpassword: vmAdminPassword
    location: locationSite1
    usePublicIP: true
    subnetId: cloud_vnet.properties.subnets[0].id
  }
}


/* ****************************** Onpre-Vnet ****************************** */

module defaultNSGSite2 '../modules/nsg.bicep' = {
  name: 'NetworkSecurityGroupSite2'
  params:{
    location: locationSite2
    name: 'nsg-site2'  
  }
}

resource onpre_vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'onpre-vnet'
  location: locationSite2
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.100.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.100.0.0/24'
          networkSecurityGroup: { id: defaultNSGSite2.outputs.nsgId }
        }
      }
    ]
  }
}


module nva '../modules/ubuntu22.04.bicep' = {
  name: 'nva'
  params: {
    vmName: 'nva'
    VMadminUsername: vmAdminUsername
    VMadminpassword: vmAdminPassword
    location: locationSite2
    usePublicIP: true
    subnetId: onpre_vnet.properties.subnets[0].id
    customData: loadFileAsBase64('bootstrap.sh')
  }
}

/* ****************************** enable diagnostic logs ****************************** */

var logAnalyticsWorkspace = '${uniqueString(resourceGroup().id)}la'
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (enablediagnostics) {
  name: logAnalyticsWorkspace
  location: locationSite1
}
