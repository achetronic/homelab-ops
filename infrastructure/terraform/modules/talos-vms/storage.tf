# Create a random name for the pool to avoid collisions
resource "random_string" "volume_pool_id" {
  length = 8
  lower  = true
  min_numeric = 8
  min_lower = 0
  min_upper = 0
  min_special = 0
}

# Create a dir where all the volumes will be created
resource "libvirt_pool" "volume_pool" {
  name = "pool-${random_string.volume_pool_id.result}"
  type = "dir"
  path = "/opt/libvirt/pool-${random_string.volume_pool_id.result}"
}

resource "libvirt_volume" "os_image" {
  source = "https://github.com/siderolabs/talos/releases/download/${var.globals.talos.version}/metal-amd64.iso"
  name   = join("", ["metal-amd64-", var.globals.talos.version, ".iso"])
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
