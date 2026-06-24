locals {
  nodes        = ["pve04"]
  default_node = local.nodes[0]

  iso_config = {
    enabled = false
  }

  clone_from_template = {
    enabled     = true
    template_vm = "9000"
  }

  vault_base = {
    cpu     = 4
    memory  = 2048
    cores   = 2
    sockets = 1

    disks = [{
      size     = 50
      storage  = "rbd"
      ssd      = true
      cache    = "writethrough"
      discard  = true
      iothread = false
    }]

    boot = {
      type    = "uefi"
      machine = "q35"
    }

    features = {
      hotplug_cpu    = true
      hotplug_memory = true
      startup_order  = 5
      startup_delay  = 5
      tags           = ["vault", "ubuntu"]
      cpu_type       = "host"
      bios           = "ovmf"
    }

    cloud_init = {
      enabled  = true
      username = "ubuntu"
      ssh_keys = []
      ip_config = {
        ipv4 = {
          address = "dhcp"
        }
      }
      user_data = templatefile(
        "${get_terragrunt_dir()}/cloud-init/user-data.yaml",
        {
          ssh_public_key = get_env("SSH_PUBLIC_KEY", "")
        }
      )
    }
  }

  vault_macs = [
    "BC:24:11:CC:DD:01",
  ]

  vaults = {
    for i in range(1) : "vault-${i}" => merge(
      local.vault_base,
      {
        node_name = local.nodes[i % length(local.nodes)]
        network = {
          interfaces = [{
            bridge = "vmbr0"
            mac    = local.vault_macs[i]
          }]
        }
        cloud_init = merge(local.vault_base.cloud_init, {
          meta_data = <<-YAML
            instance-id: vault-${i}
            local-hostname: vault-${i}
          YAML
        })
      }
    )
  }

  all_vms = local.vaults
}
