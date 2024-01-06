# Create a dir where all the volumes will be created
resource "libvirt_pool" "volume_pool" {
  name = "vms-volume-pool"
  type = "dir"
  path = "/opt/libvirt/vms-volume-pool"
}

# Fetch ubuntu release image for every selected CPU architecture
resource "libvirt_volume" "os_image" {
  for_each = var.instances

  # The name of the volume is the remote file's one, but with another extension added (.qcow2)
  name   = join("", [
    element(reverse( try(split("/", each.value.diskimage), [])), 0),
    ".qcow2"
  ])

  source = each.value.diskimage
  pool   = libvirt_pool.volume_pool.name
}

# CloudInit volume to perform changes at runtime: add our ssh-key to the instance and more
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown

# Create a random string to be used as password for each instance
resource "random_string" "instance_password" {
  for_each = var.instances

  length           = 16
  special          = false
  override_special = "_%@"
}

# Create an authorized SSH key pair for each instance
resource "tls_private_key" "instance_ssh_key" {
  for_each = var.instances

  algorithm = "RSA"
  rsa_bits  = "4096"
}

locals {
  # Computed path to the directory where instances' SSH keys will be created
  computed_instances_ssh_keys_path = var.globals.io_files.instances_ssh_keys_path != null ? (
    var.globals.io_files.instances_ssh_keys_path ) : path.root
}
# Export the SSH private key for each instance
resource "local_file" "private_key" {
  depends_on = [tls_private_key.instance_ssh_key]

  for_each = var.instances

  content         = tls_private_key.instance_ssh_key[each.key].private_key_pem
  filename        = "${local.computed_instances_ssh_keys_path}/${each.key}.pem"

  file_permission = "0600"
}


locals {
  # Computed path to the directory where instances' SSH keys will be created
  computed_instances_external_ssh_keys_path = var.globals.io_files.external_ssh_keys_path != null ? (
    var.globals.io_files.external_ssh_keys_path) : path.root

  # List of SSH keys allowed on instances
  instances_external_ssh_keys = [
    for i, v in fileset(local.computed_instances_external_ssh_keys_path, "*.pub") :
    trimspace(file("${local.computed_instances_external_ssh_keys_path}/${v}"))
  ]

  # Parsed user-data config file for Cloud Init
  user_data = {
    for instance, _ in var.instances :
    instance => templatefile("${path.module}/templates/cloud-init/user_data.cfg", {
      hostname = instance
      user     = "ubuntu"
      password = random_string.instance_password[instance].result
      ssh-keys = concat(
        [tls_private_key.instance_ssh_key[instance].public_key_openssh],
        local.instances_external_ssh_keys
      )
    })
  }

  # Parsed network config file for Cloud Init
  network_config = {
    for vm_name, vm_data in local.instance_networks_expanded :
    vm_name => templatefile(
      "${path.module}/templates/cloud-init/network_config.cfg",
      { networks = vm_data }
    )
  }
}
# Volume for bootstrapping instances using Cloud Init
resource "libvirt_cloudinit_disk" "cloud_init" {
  for_each = var.instances

  name           = join("", ["cloud-init-", each.key, ".iso"])
  user_data      = local.user_data[each.key]
  network_config = local.network_config[each.key]
  pool           = libvirt_pool.volume_pool.name
}

# General purpose volumes for all the instances
resource "libvirt_volume" "instance_disk" {
  for_each = var.instances

  name           = join("", [each.key, ".qcow2"])
  base_volume_id = libvirt_volume.os_image[each.key].id
  pool           = libvirt_pool.volume_pool.name

  # 10GB (as bytes) as default
  size = try(each.value.disk, 10 * 1000 * 1000 * 1000)
}

