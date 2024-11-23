# Create the workload resources in the target host through SSH
module "compute-10-virtual-machines" {

  source = "../modules/talos-vms-grained"

  # Global configuration
  globals   = local.globals_compute_10

  # Configuration related to VMs directly
  instances = local.instances_compute_10
}

module "compute-20-virtual-machines" {

  source = "../modules/talos-vms"

  # Global configuration
  globals   = local.globals_compute_20

  # Configuration related to VMs directly
  instances = local.instances_compute_20
}
