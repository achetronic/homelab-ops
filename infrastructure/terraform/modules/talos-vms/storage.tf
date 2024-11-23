locals {
  volume_pool_base_path = "/opt/libvirt/vms-volume-pool"
}

# Create a dir where all the volumes will be created
resource "libvirt_pool" "volume_pool" {
  name = "vms-volume-pool"
  type = "dir"
  target {
    path = "${local.volume_pool_base_path}"
  }
}

# Ref: https://factory.talos.dev
resource "libvirt_volume" "os_image" {
  for_each = var.globals.iso_image_urls

  source = each.value

  name   = join("", [each.key, ".iso"])
  pool   = libvirt_pool.volume_pool.name
  format = "iso"
}

# General purpose volumes for all the instances
resource "libvirt_volume" "instance_disk" {
  for_each = var.instances

  name   = join("", [each.key, ".qcow2"])
  pool   = libvirt_pool.volume_pool.name
  format = "qcow2"

  # 10GB (as bytes) as default
  size = try(each.value.disk, 10 * 1000 * 1000 * 1000)

}
