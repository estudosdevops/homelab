terraform {
  source = "${get_repo_root()}/terraform-modules/proxmox-vm"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  cluster_config = read_terragrunt_config("${get_terragrunt_dir()}/values.hcl")
}

inputs = {
  proxmox_node_name   = local.cluster_config.locals.default_node
  clone_from_template = local.cluster_config.locals.clone_from_template
  iso_image           = local.cluster_config.locals.iso_config
  snippets_datastore  = "local"
  vms                 = local.cluster_config.locals.all_vms
}
