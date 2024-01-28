# Create the workload resources in the target host through SSH
module "compute-10-virtual-machines" {

  source = "../modules/talos-vms-grained"

  # Global configuration
  globals   = local.globals

  # Configuration related to VMs directly
  instances = local.instances
}

# Create the workload resources in the target host through SSH
#module "compute-10-virtual-machines-test" {
#
#  source = "../modules/talos-vms"
#
#  # Global configuration
#  globals   = local.globals_test
#
#  # Configuration related to VMs directly
#  instances = local.instances_test
#}
