locals {
  cluster_name = "k8s-prod"

  # Nodes disponíveis no cluster para distribuição das VMs
  nodes = ["pve01", "pve02", "pve03", "pve04"]

  # Node padrão — fallback quando a VM não define node_name
  default_node = local.nodes[0]

  # ISO do Talos Linux
  iso_config = {
    enabled  = true
    iso_path = "local:iso/talos-metal-amd64-secureboot.iso"
  }

  # ============================================================
  # Controlplanes
  # ============================================================

  # MACs fixos — reservar IPs correspondentes no DHCP
  controlplane_macs = [
    "BC:24:11:AA:BB:01",
    "BC:24:11:AA:BB:02",
    "BC:24:11:AA:BB:03",
  ]

  controlplane_base = {
    cpu     = 4
    memory  = 4096
    cores   = 2
    sockets = 1

    disks = [{
      size     = 15
      storage  = "local-lvm"
      ssd      = false
      cache    = "writethrough"
      discard  = true
      iothread = false # RBD/Ceph não suporta iothread
    }]

    boot = {
      type    = "uefi"
      machine = "q35"
    }

    features = {
      hotplug_cpu    = true
      hotplug_memory = true
      startup_order  = 10
      startup_delay  = 10
      tags           = ["k8s", "cp", "talos", "prod"]
      cpu_type       = "host"
      bios           = "ovmf"
    }
  }

  controlplanes = {
    for i in range(3) : "${local.cluster_name}-cp${i}" => merge(
      local.controlplane_base,
      {
        node_name = local.nodes[i % length(local.nodes)]
        network = {
          interfaces = [{
            bridge = "vmbr0"
            mac    = local.controlplane_macs[i]
          }]
        }
      }
    )
  }

  # ============================================================
  # Workers
  # ============================================================

  # MACs fixos — reservar IPs correspondentes no DHCP
  worker_macs = [
    "BC:24:11:AA:CC:01",
    "BC:24:11:AA:CC:02",
  ]

  worker_base = {
    cpu     = 4
    memory  = 2048
    cores   = 2
    sockets = 1

    disks = [{
      size     = 100
      storage  = "rbd"
      ssd      = false
      cache    = "writethrough"
      discard  = true
      iothread = false # RBD/Ceph não suporta iothread
    }]

    boot = {
      type    = "uefi"
      machine = "q35"
    }

    features = {
      hotplug_cpu    = true
      hotplug_memory = true
      startup_order  = 20
      startup_delay  = 10
      tags           = ["k8s", "wk", "talos", "prod"]
      cpu_type       = "host"
      bios           = "ovmf"
    }
  }

  workers = {
    for i in range(2) : "${local.cluster_name}-wk${i}" => merge(
      local.worker_base,
      {
        node_name = local.nodes[i % length(local.nodes)]
        network = {
          interfaces = [{
            bridge = "vmbr0"
            mac    = local.worker_macs[i]
          }]
        }
      }
    )
  }

  # ============================================================
  # Todas as VMs — passado para o módulo
  # ============================================================
  all_vms = merge(local.controlplanes, local.workers)
}
