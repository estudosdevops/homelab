locals {
  vms_merged = {
    for name, vm in var.vms : name => merge(
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
          tags           = []
          cpu_type       = "host"
          bios           = "ovmf"
        }
        cloud_init = {
          enabled           = false
          username          = "ubuntu"
          ssh_keys          = []
          user_data_file_id = null
          meta_data_file_id = null
          ip_config         = null
        }
        gpu_passthrough = {
          enabled    = false
          device_ids = []
        }
      },
      vm
    )
  }
}
