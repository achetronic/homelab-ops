# Create all instances
resource "libvirt_domain" "instance" {
  for_each = var.instances

  cpu {
    mode = "host-passthrough"
  }

  # Merge between global XSLT and user-defined XSLT
  # As Terraform can not perform XML parsing to merge XML,
  # some tags are deleted to avoid conflicts: xml, xsl:stylesheet, xsl:transform
  xml {
    xslt = templatefile("${path.module}/templates/xsl/global.xsl",
      {
        user_xslt = each.value.xslt != null ? each.value.xslt : ""
      }
    )
  }

  # Set config related directly to the VM
  name   = each.key
  memory = each.value.memory
  vcpu   = each.value.vcpu

  # Use UEFI capable machine
  machine    = "q35"
  firmware   = "/usr/share/OVMF/OVMF_CODE_4M.fd"


  # Setting CDROM after HDD gives the opportunity to install on first boot,
  # and boot from HDD in the following ones
  boot_device {
    dev = ["hd", "cdrom"]
  }

  # Attach MACVTAP networks
  dynamic "network_interface" {
    for_each = each.value.networks

    iterator = network
    content {
      macvtap   = network.value.interface
      hostname  = each.key
      mac       = network.value.mac
      addresses = network.value.addresses
      wait_for_lease = false
      # Guest virtualized network interface is connected directly to a physical device on the Host,
      # As a result, requested IP address can only be claimed by the OS: Linux is configured in static mode by cloud-init
    }
  }

  # Read-Only disk. Used to load ISO images on first boot
  disk {
    file = "${local.volume_pool_base_path}/${each.value.image}.iso"
  }

  # Writable disk used as a data storage
  disk {
    volume_id = libvirt_volume.instance_disk[each.key].id
    scsi = true
  }

  # IMPORTANT: this is a known bug on cloud images, since they expect a console
  # we need to pass it
  # https://bugs.launchpad.net/cloud-images/+bug/1573095
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_port = "1"
    target_type = "virtio"
  }

  video {
    type = "vga"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }

  qemu_agent = false
  autostart  = true

  lifecycle {
    ignore_changes = [
      nvram,
      disk[0],
      network_interface[0],
    ]
  }

}
