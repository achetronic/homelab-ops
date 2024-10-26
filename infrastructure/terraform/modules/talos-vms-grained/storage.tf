locals {
  default_base_url = "https://github.com/siderolabs/talos/releases/download"
  base_url = (var.globals.talos.base_url != null && var.globals.talos.base_url != "") ? var.globals.talos.base_url : local.default_base_url
}

# Create a dir where all the volumes will be created
resource "libvirt_pool" "volume_pool" {
  name = "vms-volume-pool"
  type = "dir"
  path = "/opt/libvirt/vms-volume-pool"
}

resource "libvirt_volume" "kernel" {
  source = "${local.base_url}/${var.globals.talos.version}/vmlinuz-amd64"
  name   = "kernel-${var.globals.talos.version}"
  pool   = libvirt_pool.volume_pool.name
  format = "raw"
}

resource "libvirt_volume" "initrd" {
  source = "${local.base_url}/${var.globals.talos.version}/initramfs-amd64.xz"
  name   = "initrd-${var.globals.talos.version}"
  pool   = libvirt_pool.volume_pool.name
  format = "raw"
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


