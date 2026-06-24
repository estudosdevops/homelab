resource "proxmox_virtual_environment_file" "user_data" {
  for_each = {
    for name, vm in local.vms_merged :
    name => vm
    if try(vm.cloud_init.enabled, false) && try(vm.cloud_init.user_data, "") != ""
  }

  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = coalesce(try(each.value.node_name, null), var.proxmox_node_name)

  source_raw {
    data      = each.value.cloud_init.user_data
    file_name = "${each.key}-user-data.yaml"
  }
}

resource "proxmox_virtual_environment_file" "meta_data" {
  for_each = {
    for name, vm in local.vms_merged :
    name => vm
    if try(vm.cloud_init.enabled, false) && try(vm.cloud_init.meta_data, "") != ""
  }

  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = coalesce(try(each.value.node_name, null), var.proxmox_node_name)

  source_raw {
    data      = each.value.cloud_init.meta_data
    file_name = "${each.key}-meta-data.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = local.vms_merged

  name      = each.key
  node_name = coalesce(try(each.value.node_name, null), var.proxmox_node_name)
  vm_id     = null

  started         = true
  stop_on_destroy = true

  timeout_start_vm = 300
  timeout_stop_vm  = 300

  machine = try(each.value.boot.machine, "q35")
  bios    = try(each.value.features.bios, "ovmf")

  boot_order = ["scsi0"]

  dynamic "cdrom" {
    for_each = (var.iso_image.enabled && !try(each.value.cloud_init.enabled, false)) ? [1] : []
    content {
      file_id   = var.iso_image.iso_path
      interface = "ide3"
    }
  }

  dynamic "clone" {
    for_each = var.clone_from_template.enabled ? [1] : []
    content {
      vm_id = var.clone_from_template.template_vm
    }
  }

  cpu {
    cores   = each.value.cores
    sockets = each.value.sockets
    type    = try(each.value.features.cpu_type, "host")
  }

  memory {
    dedicated = each.value.memory
  }

  dynamic "efi_disk" {
    for_each = try(each.value.features.bios, "ovmf") == "ovmf" ? [1] : []
    content {
      datastore_id = each.value.disks[0].storage
      type         = "4m"
    }
  }

  agent {
    enabled = true
  }

  scsi_hardware = var.scsi_hardware

  dynamic "disk" {
    for_each = each.value.disks
    content {
      datastore_id = disk.value.storage
      size         = disk.value.size
      interface    = disk.key == 0 ? "scsi0" : "scsi${disk.key}"
      iothread     = try(disk.value.iothread, true)
      ssd          = disk.value.ssd
      discard      = disk.value.discard ? "on" : "ignore"
      cache        = disk.value.cache
    }
  }

  dynamic "network_device" {
    for_each = each.value.network.interfaces
    content {
      bridge      = network_device.value.bridge
      mtu         = network_device.value.mtu
      mac_address = try(network_device.value.mac, null)
      rate_limit  = network_device.value.rate
      vlan_id     = network_device.value.vlan_id
    }
  }

  dynamic "initialization" {
    for_each = try(each.value.cloud_init.enabled, false) ? [1] : []
    content {
      user_account {
        username = try(each.value.cloud_init.username, "ubuntu")
        keys     = try(each.value.cloud_init.ssh_keys, [])
      }

      dynamic "ip_config" {
        for_each = try(each.value.cloud_init.ip_config, null) != null ? [each.value.cloud_init.ip_config] : []
        content {
          dynamic "ipv4" {
            for_each = try(ip_config.value.ipv4, null) != null ? [ip_config.value.ipv4] : []
            content {
              address = try(ipv4.value.address, "dhcp")
              gateway = try(ipv4.value.gateway, null)
            }
          }
        }
      }

      user_data_file_id = try(
        proxmox_virtual_environment_file.user_data[each.key].id,
        try(each.value.cloud_init.user_data_file_id, null)
      )

      meta_data_file_id = try(
        proxmox_virtual_environment_file.meta_data[each.key].id,
        try(each.value.cloud_init.meta_data_file_id, null)
      )
    }
  }

  dynamic "startup" {
    for_each = try(each.value.features.startup_order, null) != null ? [1] : []
    content {
      order    = each.value.features.startup_order
      up_delay = try(each.value.features.startup_delay, 0)
    }
  }

  tags = each.value.features.tags
}
