targetScope = 'resourceGroup'

/*
  Virtual network for the simulated insurance estate.

  Three subnets model the tiers an operations audience expects to see: web, app
  and data. Each gets its own network security group so the tier boundaries are
  visible in the portal rather than implied by naming alone.

  Two deliberate choices:

  1. No workload VM receives a public IP address, and there is no NAT gateway.
     This subscription blocks public IP address creation outright, so egress
     relies on platform-supplied default outbound access. That is a constraint
     of the target subscription rather than a design preference, and it is
     recorded here because it bounds what the estate can reach.

  2. No inbound rule permits the internet. The demonstration is observed entirely
     through the Azure portal, so nothing needs to reach these machines. Guest
     interaction, when required, uses Run Command, which travels over the Azure
     control plane rather than an open port.
*/

param baseName string
param location string
param tags object

@description('Address space for the estate virtual network.')
param addressPrefix string = '10.10.0.0/16'

var webSubnetPrefix = '10.10.1.0/24'
var appSubnetPrefix = '10.10.2.0/24'
var dataSubnetPrefix = '10.10.3.0/24'

// Each tier denies inbound from the internet outright. Intra-VNet traffic is
// permitted so the tiers can talk to each other, which is what makes the
// VM Insights dependency map interesting.
resource webNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-web-${baseName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource appNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-app-${baseName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource dataNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-data-${baseName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowAppTierInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: appSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-${baseName}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-web'
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: {
            id: webNsg.id
          }
        }
      }
      {
        name: 'snet-app'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: appNsg.id
          }
        }
      }
      {
        name: 'snet-data'
        properties: {
          addressPrefix: dataSubnetPrefix
          networkSecurityGroup: {
            id: dataNsg.id
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output webSubnetId string = vnet.properties.subnets[0].id
output appSubnetId string = vnet.properties.subnets[1].id
output dataSubnetId string = vnet.properties.subnets[2].id
