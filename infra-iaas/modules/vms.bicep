targetScope = 'resourceGroup'

/*
  The simulated insurance estate, as infrastructure-as-a-service.

  Six Ubuntu virtual machines across three tiers (web, application, data). These
  are real machines producing real telemetry: real CPU, real memory, real disk,
  real TCP connections between tiers.

  The inter-tier traffic matters. VM Insights builds its dependency Map from TCP
  connections observed by the Dependency Agent, so the estate has to actually
  talk to itself for the Map to show anything. Each machine therefore runs two
  tiny services laid down by cloud-init: a listener on its tier's port, and a
  client loop that calls the tier below it. Web calls application, application
  calls data, data terminates the chain. That produces a genuine three-tier
  topology in the portal rather than a drawing.

  Every machine also carries stress-ng, which is what lets a presenter induce a
  real CPU or memory condition on stage and have a real Azure Monitor alert fire
  from it. Nothing about the alert is faked.

  Security posture:
    - No public IP address on any workload machine.
    - Password authentication disabled; SSH public key only.
    - System-assigned managed identity, so no credential is ever stored.
    - Guest interaction uses Run Command over the Azure control plane.
*/

param location string
param tags object
param webSubnetId string
param appSubnetId string
param dataSubnetId string

@description('SSH public key for the administrator account. A public key is not a secret.')
param adminPublicKey string

@description('Administrator user name for the estate virtual machines.')
param adminUsername string = 'uoiadmin'

@description('Virtual machine size. A 2 vCPU size keeps a six-machine estate inexpensive.')
param vmSize string = 'Standard_D2ls_v7'

@description('''
Daily auto-shutdown time for every estate machine, as HHmm in the time zone
below. This is a cost backstop, not a demonstration feature: the estate is
normally left deallocated between demonstrations, and this ensures a machine
started for a demonstration and then forgotten does not bill for weeks.
''')
param autoShutdownTime string = '2300'

@description('Time zone for the auto-shutdown schedule, as a Windows time zone identifier.')
param autoShutdownTimeZone string = 'UTC'

@description('Set to false to deploy the estate without an auto-shutdown schedule.')
param enableAutoShutdown bool = true

// Static addresses so cloud-init can be told, at deployment time, exactly which
// machines to call. Dynamic addressing would make the dependency topology
// non-deterministic and the Map unreliable on stage.
var estate = [
  {
    name: 'vm-web-01'
    tier: 'web'
    role: 'Policy portal web front end'
    subnetId: webSubnetId
    ip: '10.10.1.10'
    zone: '1'
    listenPort: 80
    targets: '10.10.2.10:8080 10.10.2.11:8080'
  }
  {
    name: 'vm-web-02'
    tier: 'web'
    role: 'Policy portal web front end'
    subnetId: webSubnetId
    ip: '10.10.1.11'
    zone: '2'
    listenPort: 80
    targets: '10.10.2.10:8080 10.10.2.11:8080'
  }
  {
    name: 'vm-app-01'
    tier: 'app'
    role: 'Claims processing application service'
    subnetId: appSubnetId
    ip: '10.10.2.10'
    zone: '1'
    listenPort: 8080
    targets: '10.10.3.10:1433 10.10.3.11:1433'
  }
  {
    name: 'vm-app-02'
    tier: 'app'
    role: 'Claims processing application service'
    subnetId: appSubnetId
    ip: '10.10.2.11'
    zone: '2'
    listenPort: 8080
    targets: '10.10.3.10:1433 10.10.3.11:1433'
  }
  {
    name: 'vm-sql-01'
    tier: 'data'
    role: 'Claims database node'
    subnetId: dataSubnetId
    ip: '10.10.3.10'
    zone: '1'
    listenPort: 1433
    targets: ''
  }
  {
    name: 'vm-sql-02'
    tier: 'data'
    role: 'Claims database node'
    subnetId: dataSubnetId
    ip: '10.10.3.11'
    zone: '2'
    listenPort: 1433
    targets: ''
  }
]

/*
  cloud-init template. {0} is the listener port, {1} the space-separated list of
  downstream targets. Written as one string so the estate topology stays defined
  in exactly one place, alongside the addresses it refers to.

  Nothing here installs a package. This subscription forbids public IP addresses,
  so the estate cannot be assumed to reach an Ubuntu archive. Both the listener
  and the load generator are therefore built only from what ships in the base
  image: python3 and coreutils. The load generator uses sha256sum against
  /dev/zero, which saturates a core just as effectively as a stress tool and
  needs nothing installed.
*/
var cloudInitTemplate = '''#cloud-config
write_files:
  - path: /opt/uoi/traffic.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # Generates the inter-tier TCP connections that VM Insights maps.
      TARGETS="{1}"
      while true; do
        for t in $TARGETS; do
          curl -s -m 5 "http://$t/" > /dev/null 2>&1 || true
        done
        sleep 5
      done
  - path: /opt/uoi/load.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # Induces a genuine CPU condition so a real Azure Monitor alert can fire.
      # Usage: load.sh [seconds] [workers]
      DURATION=$1
      WORKERS=$2
      if [ -z "$DURATION" ]; then DURATION=600; fi
      if [ -z "$WORKERS" ]; then WORKERS=2; fi
      for i in $(seq 1 $WORKERS); do
        timeout "$DURATION" sha256sum /dev/zero &
      done
      wait
  - path: /etc/systemd/system/uoi-listener.service
    content: |
      [Unit]
      Description=UOI synthetic tier listener
      After=network.target
      [Service]
      ExecStart=/usr/bin/python3 -m http.server {0} --directory /opt/uoi/www
      Restart=always
      [Install]
      WantedBy=multi-user.target
  - path: /etc/systemd/system/uoi-traffic.service
    content: |
      [Unit]
      Description=UOI synthetic inter-tier traffic
      After=network.target
      [Service]
      ExecStart=/opt/uoi/traffic.sh
      Restart=always
      [Install]
      WantedBy=multi-user.target
runcmd:
  - mkdir -p /opt/uoi/www
  - echo 'Synthetic Demo Data' > /opt/uoi/www/index.html
  - systemctl daemon-reload
  - systemctl enable --now uoi-listener
  - systemctl enable --now uoi-traffic
'''

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = [
  for machine in estate: {
    name: 'nic-${machine.name}'
    location: location
    tags: union(tags, { tier: machine.tier })
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            privateIPAllocationMethod: 'Static'
            privateIPAddress: machine.ip
            subnet: {
              id: machine.subnetId
            }
          }
        }
      ]
    }
  }
]

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = [
  for (machine, index) in estate: {
    name: machine.name
    location: location
    tags: union(tags, {
      tier: machine.tier
      role: machine.role
      isSynthetic: 'true'
      dataClassification: 'Synthetic Demo Data'
    })
    zones: [
      machine.zone
    ]
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      hardwareProfile: {
        vmSize: vmSize
      }
      storageProfile: {
        imageReference: {
          // Ubuntu 22.04 LTS, generation 2. Not 24.04: the Dependency Agent that
          // feeds the VM Insights Map refuses to install on 24.04, reporting
          // "Unsupported distribution". The Map is a core part of the native
          // portal story, so the distribution is pinned to the newest release
          // the agent actually supports.
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
          deleteOption: 'Delete'
        }
      }
      osProfile: {
        computerName: machine.name
        adminUsername: adminUsername
        customData: base64(format(cloudInitTemplate, machine.listenPort, machine.targets))
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${adminUsername}/.ssh/authorized_keys'
                keyData: adminPublicKey
              }
            ]
          }
          patchSettings: {
            patchMode: 'AutomaticByPlatform'
            assessmentMode: 'AutomaticByPlatform'
          }
        }
      }
      networkProfile: {
        networkInterfaces: [
          {
            id: nic[index].id
            properties: {
              deleteOption: 'Delete'
            }
          }
        ]
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
        }
      }
      // Current-generation sizes expect Trusted Launch. Secure boot and a
      // virtual TPM are enabled because there is no reason to run a
      // demonstration estate in a weaker posture than a real one.
      securityProfile: {
        securityType: 'TrustedLaunch'
        uefiSettings: {
          secureBootEnabled: true
          vTpmEnabled: true
        }
      }
    }
  }
]

// Azure Monitor Agent. This is what delivers performance counters and syslog
// into the workspace via the data collection rules.
resource azureMonitorAgent 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = [
  for (machine, index) in estate: {
    parent: vm[index]
    name: 'AzureMonitorLinuxAgent'
    location: location
    tags: tags
    properties: {
      publisher: 'Microsoft.Azure.Monitor'
      type: 'AzureMonitorLinuxAgent'
      typeHandlerVersion: '1.0'
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: true
      settings: {}
    }
  }
]

// Dependency Agent is deliberately absent.
//
// It is the agent behind the VM Insights "Map" tab, and it will not install on
// any current Ubuntu release: it reports "Unsupported distribution" on both
// 24.04 and 22.04.5, and its newest published build is 9.9.1, which predates
// them. Downgrading the estate to an older distribution to satisfy a stalled
// agent would be the wrong trade.
//
// Consequence, stated plainly: the native Map tab will not render a topology.
// Performance charts, metrics and alerts are unaffected, because those come
// from the Azure Monitor Agent above. The estate topology is instead presented
// in the workbook, built from the estate definition and live metrics.

// Cost backstop. Six D2ls_v7 machines bill about $17.28/day while running and
// nothing but disk while deallocated, so the expensive failure mode is not the
// estate existing - it is the estate being started for a demonstration and
// then left running. A daily shutdown bounds that to a single day.
//
// This does not start the machines. Deallocated machines stay deallocated and
// the schedule simply finds nothing to do.
resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = [
  for (machine, index) in estate: if (enableAutoShutdown) {
    name: 'shutdown-computevm-${machine.name}'
    location: location
    tags: tags
    properties: {
      status: 'Enabled'
      taskType: 'ComputeVmShutdownTask'
      dailyRecurrence: {
        time: autoShutdownTime
      }
      timeZoneId: autoShutdownTimeZone
      notificationSettings: {
        status: 'Disabled'
      }
      targetResourceId: vm[index].id
    }
  }
]

output vmNames array = [for (machine, index) in estate: machine.name]
output vmIds array = [for (machine, index) in estate: vm[index].id]
output vmPrincipalIds array = [for (machine, index) in estate: vm[index].identity.principalId]
output estateDefinition array = estate
