variable "proxmox_node_name" {
  type        = string
  description = "Node padrão do Proxmox onde as VMs serão criadas (pode ser sobrescrito por VM via node_name)"
  nullable    = false
}

variable "snippets_datastore" {
  type        = string
  default     = "local"
  description = "Datastore do Proxmox onde os snippets de cloud-init serão armazenados. Precisa ter o tipo 'Snippets' habilitado em Datacenter > Storage."
}

variable "vms" {
  type = map(object({
    node_name = optional(string)

    cpu     = number
    memory  = number
    cores   = number
    sockets = optional(number, 1)

    disks = list(object({
      size     = number
      storage  = string
      ssd      = optional(bool, false)
      cache    = optional(string, "writethrough")
      discard  = optional(bool, true)
      iothread = optional(bool, true)
    }))

    network = object({
      interfaces = list(object({
        bridge  = string
        mac     = optional(string)
        vlan_id = optional(number)
        mtu     = optional(number)
        rate    = optional(number)
      }))
    })

    boot = optional(object({
      type    = optional(string, "uefi")
      machine = optional(string, "q35")
    }), {})

    features = optional(object({
      hotplug_cpu    = optional(bool, true)
      hotplug_memory = optional(bool, true)
      startup_order  = optional(number)
      startup_delay  = optional(number)
      tags           = optional(list(string), [])
      cpu_type       = optional(string, "host")
      bios           = optional(string, "ovmf")
    }), {})

    cloud_init = optional(object({
      enabled  = bool
      username = optional(string, "ubuntu")
      ssh_keys = optional(list(string), [])

      # Conteúdo YAML inline — o módulo cria o snippet no Proxmox automaticamente
      # O datastore é controlado pela variável snippets_datastore
      user_data = optional(string, "")
      meta_data = optional(string, "")

      ip_config = optional(object({
        ipv4 = optional(object({
          address = optional(string, "dhcp")
          gateway = optional(string)
        }))
      }))
    }))

    gpu_passthrough = optional(object({
      enabled    = bool
      device_ids = optional(list(string), [])
    }), { enabled = false })
  }))

  description = "Mapa de VMs a criar. A chave é o nome da VM."
  nullable    = false

  validation {
    condition     = alltrue([for k, v in var.vms : v.cpu > 0 && v.memory > 0 && v.cores > 0])
    error_message = "CPU, memory, and cores must be greater than 0."
  }

  validation {
    condition     = alltrue([for k, v in var.vms : alltrue([for d in v.disks : d.size > 0])])
    error_message = "Disk sizes must be greater than 0."
  }

  validation {
    condition     = alltrue([for k, v in var.vms : length(v.network.interfaces) > 0])
    error_message = "Each VM must have at least one network interface."
  }
}

variable "clone_from_template" {
  type = object({
    enabled     = optional(bool, false)
    template_vm = optional(string, "")
  })
  default     = {}
  description = "Clone VM from template. Mutuamente exclusivo com iso_image."
}

variable "iso_image" {
  type = object({
    enabled  = optional(bool, false)
    iso_path = optional(string, "")
  })
  default     = {}
  description = "Boot via ISO. Mutuamente exclusivo com clone_from_template."
}

variable "scsi_hardware" {
  type        = string
  default     = "virtio-scsi-pci"
  description = "Tipo do controlador SCSI. Opções: virtio-scsi-pci, virtio-scsi-single, lsi, lsi53c810, megasas, pvscsi."

  validation {
    condition     = contains(["virtio-scsi-pci", "virtio-scsi-single", "lsi", "lsi53c810", "megasas", "pvscsi"], var.scsi_hardware)
    error_message = "scsi_hardware must be one of: virtio-scsi-pci, virtio-scsi-single, lsi, lsi53c810, megasas, pvscsi."
  }
}
