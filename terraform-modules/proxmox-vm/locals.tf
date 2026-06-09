locals {
  # Merge defaults with user-provided config
  vms_merged = {
    for name, vm in var.vms : name => merge(
      # Defaults
      {
        boot = {
          type    = "uefi"
          machine = "q35"
        }
        features = {
          hotplug_cpu    = true
          hotplug_memory = true
          startup_order  = null
          startup_delay  = null
          pool           = null
          tags           = []
          cpu_type       = "host"
          bios           = "ovmf"
        }
        cloud_init = {
          enabled        = false
          user_data      = ""
          meta_data      = ""
          network_config = ""
        }
        gpu_passthrough = {
          enabled    = false
          device_ids = []
        }
      },
      # User-provided values (overrides defaults)
      vm
    )
  }

  # Flatten network interfaces for easier iteration
  vm_network_interfaces = flatten([
    for vm_name, vm_config in local.vms_merged : [
      for idx, nic in vm_config.network.interfaces : {
        vm_name = vm_name
        nic_idx = idx
        bridge  = nic.bridge
        mac     = nic.mac
        vlan_id = nic.vlan_id
        mtu     = nic.mtu
        rate    = nic.rate
      }
    ]
  ])

  # Flatten disks for easier iteration
  vm_disks = flatten([
    for vm_name, vm_config in local.vms_merged : [
      for idx, disk in vm_config.disks : {
        vm_name  = vm_name
        disk_idx = idx
        size     = disk.size
        storage  = disk.storage
        ssd      = disk.ssd
        cache    = disk.cache
        discard  = disk.discard
      }
    ]
  ])

  # Get sorting order for startup
  startup_order_enabled = {
    for name, vm in local.vms_merged : name => vm.features.startup_order
    if vm.features.startup_order != null
  }
}
