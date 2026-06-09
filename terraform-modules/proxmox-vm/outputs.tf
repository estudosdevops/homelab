output "vms" {
  description = "Map of all created VMs with details"
  value = {
    for name, vm in proxmox_virtual_environment_vm.vm : name => {
      id   = vm.vm_id
      name = vm.name
      node = vm.node_name
    }
  }
}

output "vm_names" {
  description = "List of all created VM names"
  value       = keys(proxmox_virtual_environment_vm.vm)
}

output "vm_ids" {
  description = "Map of VM names to their Proxmox IDs"
  value = {
    for name, vm in proxmox_virtual_environment_vm.vm : name => vm.vm_id
  }
}
