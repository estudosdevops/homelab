locals {
  cluster_name = "kube-prod"

  # Nodes disponíveis no cluster para distribuição das VMs
  nodes = ["pve01", "pve02", "pve03", "pve04"]

  # Node padrão — fallback quando a VM não define node_name
  default_node = local.nodes[0]

  # ISO do Talos Linux
  iso_config = {
    enabled  = true
    iso_path = "local:iso/talos-linux-metal-amd64.iso"
  }

  # ============================================================
  # Controlplanes
  # ============================================================

  # MACs fixos — reservar IPs correspondentes no DHCP
  controlplane_macs = [
    "BC:24:11:AA:BB:01",
  ]

  controlplane_base = {
    cpu     = 4
    memory  = 4096
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
      startup_order  = 10
      startup_delay  = 10
      tags           = ["k8s", "cp", "talos", "prod"]
      cpu_type       = "host"
      bios           = "ovmf"
    }
  }

  controlplanes = {
    for i in range(1) : "${local.cluster_name}-cp${i}" => merge(
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
  # Todas as VMs — passado para o módulo
  # ============================================================
  all_vms = merge(local.controlplanes)
}
