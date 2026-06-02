resource "proxmox_virtual_environment_vm" "vm" {
  for_each = local.vms_merged

  name      = each.key
  node_name = coalesce(try(each.value.node_name, null), var.proxmox_node_name)
  vm_id     = null

  # Aguarda o boot completo (requer QEMU Guest Agent ativo na VM)
  started         = true
  stop_on_destroy = true

  timeout_start_vm = 300
  timeout_stop_vm  = 300

  # Tipo de máquina (q35 ou i440fx)
  machine = try(each.value.boot.machine, "q35")

  # BIOS (ovmf = UEFI, seabios = legado)
  bios = try(each.value.features.bios, "ovmf")

  # Ordem de boot — disco primeiro
  boot_order = ["scsi0"]

  # Clone ou ISO
  dynamic "clone" {
    for_each = var.iso_image.enabled ? [] : [1]
    content {
      vm_id = var.clone_from_template.enabled ? var.clone_from_template.template_vm : null
    }
  }

  # CDROM/ISO Boot
  dynamic "cdrom" {
    for_each = var.iso_image.enabled ? [1] : []
    content {
      file_id   = var.iso_image.iso_path
      interface = "ide3"
    }
  }

  # CPU
  cpu {
    cores   = each.value.cores
    sockets = each.value.sockets
    type    = try(each.value.features.cpu_type, "host")
  }

  # EFI disk — obrigatório quando bios = ovmf
  dynamic "efi_disk" {
    for_each = try(each.value.features.bios, "ovmf") == "ovmf" ? [1] : []
    content {
      datastore_id = each.value.disks[0].storage
      type         = "4m"
    }
  }

  # QEMU Guest Agent
  agent {
    enabled = true
  }

  # Memory
  memory {
    dedicated = each.value.memory
  }

  # SCSI Controller
  scsi_hardware = var.scsi_hardware

  # Network
  dynamic "network_device" {
    for_each = each.value.network.interfaces
    content {
      bridge      = network_device.value.bridge
      mtu         = network_device.value.mtu
      mac_address = try(network_device.value.mac, null) != null ? network_device.value.mac : null
      rate_limit  = network_device.value.rate
      vlan_id     = network_device.value.vlan_id
    }
  }

  # Storage
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

  # Startup order
  dynamic "startup" {
    for_each = try(each.value.features.startup_order, null) != null ? [1] : []
    content {
      order    = each.value.features.startup_order
      up_delay = try(each.value.features.startup_delay, 0)
    }
  }

  # Tags
  tags = each.value.features.tags
}
