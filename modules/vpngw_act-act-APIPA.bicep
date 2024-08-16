param location string
param gatewayName string
param vnetName string
param bgpAsn int = 0
param bgpperingaddress string
param customBgpIpAddress1 string
param customBgpIpAddress2 string
param enablePrivateIpAddress bool = false
param useExisting bool = false
param logAnalyticsId string
param enablediagnostics bool


resource vnet01 'Microsoft.Network/virtualNetworks@2023-04-01' existing =  {
  name: vnetName
  resource GatewaySubnet 'subnets' existing = {
    name: 'GatewaySubnet'
  }
}

resource vpngwpip1 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${gatewayName}-pip1'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource vpngwpip2 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${gatewayName}-pip2'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}


resource vpngw 'Microsoft.Network/virtualNetworkGateways@2021-08-01' = if (!useExisting) {
  name: gatewayName
  location: location
  properties: {
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: { id: vpngwpip1.id }
          subnet: { id: vnet01::GatewaySubnet.id }
        }
      }
      {
        name: 'ipconfig2'
        properties: {
          publicIPAddress: { id: vpngwpip2.id }
          subnet: { id: vnet01::GatewaySubnet.id }
        }
      }

    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    activeActive:true
    enableBgp: bgpAsn == 0 ? false : true
    bgpSettings: {
      asn: bgpAsn
      bgpPeeringAddress:bgpperingaddress
      bgpPeeringAddresses: [
        {
          ipconfigurationId: concat(resourceId('Microsoft.Network/virtualNetworkGateways', 'cloud-vpngw'), '/ipConfigurations/ipconfig1')
          customBgpIpAddresses: [customBgpIpAddress1]
        }
        {
          ipconfigurationId: concat(resourceId('Microsoft.Network/virtualNetworkGateways', 'cloud-vpngw'), '/ipConfigurations/ipconfig2')
          customBgpIpAddresses: [customBgpIpAddress2]
        }
      ]
    }
    enablePrivateIpAddress: enablePrivateIpAddress
  }
}


resource extvpngw 'Microsoft.Network/virtualNetworkGateways@2022-01-01' existing = if (useExisting) {
  name: gatewayName  
}

/* ****************************** enable diagnostic logs ****************************** */

resource diagnosticLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enablediagnostics){
  name: '${vpngw.name}-logs'
  scope:vpngw
  properties: {
    workspaceId: logAnalyticsId
    logs: [
      {
        category: null
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}
  
output vpngwName string = !useExisting ? vpngw.name : extvpngw.name
output vpngwId string = !useExisting ? vpngw.id : extvpngw.id
output bgpPeeringAddress string = !useExisting ? vpngw.properties.bgpSettings.bgpPeeringAddress : extvpngw.properties.bgpSettings.bgpPeeringAddress
output publicIp01Name string = vpngwpip1.name
output publicIp01Address string = vpngwpip1.properties.ipAddress
output publicIp02Name string = vpngwpip2.name
output publicIp02Address string = vpngwpip2.properties.ipAddress
