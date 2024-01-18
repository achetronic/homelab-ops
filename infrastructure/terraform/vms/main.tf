# Create the workload resources in the target host through SSH
module "compute-10-virtual-machines" {

  source = "../modules/talos-vms"

  # Global configuration
  globals   = local.globals

  # Configuration related to VMs directly
  instances = local.instances
}
