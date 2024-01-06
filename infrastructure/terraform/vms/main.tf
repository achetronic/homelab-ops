# Create the workload resources in the target host through SSH
module "compute-01-virtual-machines" {

  source = "../modules/vms"

  # Global configuration
  globals   = local.globals

  # Configuration related to VMs directly
  networks  = local.networks
  instances = local.instances
}
