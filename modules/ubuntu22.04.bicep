param location string
param zones array = []

param subnetId string
param vmName string
param VMadminUsername string = ''
@secure()
param VMadminpassword string
param hostGroupId string = ''
param hostId string = ''
param vmSize string = 'Standard_D2s_v3'
param enableManagedIdentity bool = false
param privateIpAddress string = ''
param nicnsg string = ''
param customData string = ''
param enableNetWatchExtention bool = false
param enableIPForwarding bool = false
param usePublicIP bool = false
param enableAcceleratedNetworking bool = false
param avsetId string = ''
param applicationGatewayBackendAddressPoolsId string = ''
param loadBalancerBackendAddressPoolsId string = ''
var vmNameSuffix = replace(vmName, 'vm-', '')
param useExistingVM bool = false

resource vmpip 'Microsoft.Network/publicIPAddresses@2023-04-01' = if (usePublicIP) {
  name: '${vmNameSuffix}-pip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    deleteOption: 'Delete'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: 'nic-${vmNameSuffix}'
  location: location
  properties: {
    networkSecurityGroup: nicnsg != '' ? { id: nicnsg } : null
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: privateIpAddress != '' ? 'Static' : 'Dynamic'
          privateIPAddress: privateIpAddress != '' ? privateIpAddress : null
          publicIPAddress: usePublicIP ? { id: vmpip.id } : null
          loadBalancerBackendAddressPools: loadBalancerBackendAddressPoolsId != '' ? [
            { id: loadBalancerBackendAddressPoolsId }
          ] : []
          applicationGatewayBackendAddressPools: applicationGatewayBackendAddressPoolsId != '' ? [
            { id: applicationGatewayBackendAddressPoolsId }
          ] : []
        }
      }
    ]
    enableIPForwarding: enableIPForwarding
    enableAcceleratedNetworking: enableAcceleratedNetworking
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = if (!useExistingVM) {
  name: vmName
  location: location
  identity: enableManagedIdentity ? { type: 'SystemAssigned' } : null
  zones: zones
  properties: {
    hostGroup: hostGroupId != '' ? { id: hostGroupId } : null
    host: hostId != '' ? { id: hostId } : null
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption: 'Delete'
      }
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: VMadminUsername
      adminPassword: VMadminpassword
      customData: customData == '' ? null : customData
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    availabilitySet: avsetId == '' ? null : { id: avsetId }
  }

  resource netWatchExt 'extensions' = if (enableNetWatchExtention) {
    name: 'AzureNetworkWatcherExtension'
    location: location
    properties: {
      autoUpgradeMinorVersion: true
      publisher: 'Microsoft.Azure.NetworkWatcher'
      type: 'NetworkWatcherAgentLinux'
      typeHandlerVersion: '1.4'
    }
  }
}


output vmName string = vm.name
output vmId string = vm.id
output nicName string = nic.name
output privateIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output principalId string = enableManagedIdentity ? vm.identity.principalId : ''
output publicIP string = vmpip.properties.ipAddress
