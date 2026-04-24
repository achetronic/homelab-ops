locals {
  volume_pool_base_path = "/opt/libvirt/vms-volume-pool"
}

# Create a dir where all the volumes will be created
resource "libvirt_pool" "volume_pool" {
  name = "vms-volume-pool"
  type = "dir"
  target = {
    path = "${local.volume_pool_base_path}"
  }

  # The provider's Read() does not recover `target` on pools that were
  # imported after a 0.8.x -> 0.9.x schema migration. The real libvirt
  # pool is already pointing to the right path; just don't let TF try to
  # rewrite the pool definition on every plan.
  lifecycle {
    ignore_changes = [
      target,
    ]
  }
}

# Ref: https://factory.talos.dev
resource "libvirt_volume" "os_image" {
  for_each = var.globals.iso_image_urls

  create = {
    content = {
      url = each.value
    }
  }

  name = join("", [each.key, ".iso"])
  pool = libvirt_pool.volume_pool.name
  target = {
    format = {
      type = "iso"
    }
  }

  # `create` is only used at resource creation (URL upload). Once the
  # volume exists, libvirt doesn't store the source URL so we can't
  # reconcile it on read; ignore it to avoid perpetual diffs.
  #
  # `target` cannot be updated in place (libvirt_volume has no Update implementation),
  # and the ISO on disk is already in the right format, so let the state stay as-is.
  lifecycle {
    ignore_changes = [
      create,
      target,
    ]
  }
}

# General purpose volumes for all the instances
resource "libvirt_volume" "instance_disk" {
  for_each = var.instances

  name = join("", [each.key, ".qcow2"])
  pool = libvirt_pool.volume_pool.name
  target = {
    format = {
      type = "qcow2"
    }
  }

  # 10GB (as bytes) as default
  capacity = try(each.value.disk, 10 * 1000 * 1000 * 1000)

  # `target` cannot be updated in place (libvirt_volume has no Update implementation).
  # The qcow2 file on disk is already in the right format.
  #
  # `capacity` is also immutable from Terraform's perspective. It will falsely
  # show as an in-place update in the plan, but will fail with "Update Not Supported" during apply.
  # To resize a disk, do it on the hypervisor manually (qemu-img resize) and ignore the changes here.
  lifecycle {
    ignore_changes = [
      target,
      capacity,
    ]
  }
}
