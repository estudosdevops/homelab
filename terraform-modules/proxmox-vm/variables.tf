variable "proxmox_node_name" {
  type        = string
  description = "Node padrão do Proxmox onde as VMs serão criadas (pode ser sobrescrito por VM via node_name)"
  nullable    = false
}

variable "vms" {
  type = map(object({
    node_name = optional(string) # Sobrescreve proxmox_node_name para esta VM específica

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
      iothread = optional(bool, true) # Desabilitar para storage RBD/Ceph
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
      enabled        = bool
      user_data      = optional(string, "")
      meta_data      = optional(string, "")
      network_config = optional(string, "")
    }))

    gpu_passthrough = optional(object({
      enabled    = bool
      device_ids = optional(list(string), [])
    }), { enabled = false })
  }))

  description = "Map de VMs a criar. Cada VM pode definir node_name para sobrescrever o node padrão."
  nullable    = false

  validation {
    condition = alltrue([
      for k, v in var.vms :
      v.cpu > 0 && v.memory > 0 && v.cores > 0
    ])
    error_message = "CPU, memory, and cores must be greater than 0."
  }

  validation {
    condition = alltrue([
      for k, v in var.vms :
      alltrue([for disk in v.disks : disk.size > 0])
    ])
    error_message = "Disk sizes must be greater than 0."
  }

  validation {
    condition = alltrue([
      for k, v in var.vms :
      length(v.network.interfaces) > 0
    ])
    error_message = "Each VM must have at least one network interface."
  }
}

variable "clone_from_template" {
  type = object({
    enabled     = optional(bool, false)
    template_vm = optional(string, "")
  })
  default     = {}
  description = "Clone VM from template (opcional, mutuamente exclusivo com iso_image)"
}

variable "iso_image" {
  type = object({
    enabled  = optional(bool, false)
    iso_path = optional(string, "")
  })
  default     = {}
  description = "Boot via ISO em vez de clone de template (opcional, mutuamente exclusivo com clone_from_template)"
}

variable "scsi_hardware" {
  type        = string
  default     = "virtio-scsi-pci"
  description = "Tipo do controlador SCSI. Opções: virtio-scsi-pci (padrão, Linux/Talos), virtio-scsi-single, lsi, lsi53c810, megasas, pvscsi."

  validation {
    condition = contains(
      ["virtio-scsi-pci", "virtio-scsi-single", "lsi", "lsi53c810", "megasas", "pvscsi"],
      var.scsi_hardware
    )
    error_message = "scsi_hardware must be one of: virtio-scsi-pci, virtio-scsi-single, lsi, lsi53c810, megasas, pvscsi."
  }
}
