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
  # firmware   = "/usr/share/OVMF/OVMF_CODE.fd" # Old Ubuntu server versions
  firmware   = "/usr/share/ovmf/OVMF.fd"        # New Ubuntu server versions

  # You may be wondering why I'm using directly these params instead of released metal ISO image.
  # Well, hard to say, but you can not set kernel params on a crafted image...
  # and I wanted to set some initial things through the machine config YAML on this stage
  initrd = libvirt_volume.initrd.id
  kernel = libvirt_volume.kernel.id

  # Ref: https://www.talos.dev/v1.6/reference/kernel/
  cmdline = [{

    # Args retrieved directly from ISO image
    console                = "ttyS0"       # Serial console for kernel output.
    console                = "tty0"        # Virtual terminal console for kernel output.
    consoleblank           = 0             # Control auto-blanking of the console after inactivity (0 to disable).
    "nvme_core.io_timeout" = 4294967295    # Set maximum I/O timeout for NVMe devices in milliseconds (max value).
    "printk.devkmsg"       = "on"          # Enable real-time logging of device kmsg messages.
    ima_template           = "ima-ng"      # Specify the Integrity Measurement Architecture (IMA) template to use.
    ima_appraise           = "fix"         # Configure IMA file appraisal mode (e.g., "fix" to repair).
    ima_hash               = "sha512"      # Set the hash algorithm used by IMA to verify file integrity.

    # Required (and recommended) args by Talos Team
    "talos.platform" = "metal"             # Platform for running Talos (e.g., "metal" for physical hardware).
    pti              = "on"                # Enable Page Table Isolation (PTI) vulnerability mitigation.
    init_on_alloc    = 1                   # Initialize allocated memory pages (1 to enable, 0 to disable).

    #"talos.config"   = "metal-iso"         # Specify the Talos configuration (e.g., "metal-iso" for ISO installation mode).
    #"talos.hostname" = each.key
    #"talos.experimental.wipe" = "system"
  },{
    _                = "slab_nomerge"      # Unspecified parameter, may be a custom or system-specific setting.
  }]

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
    type = "qxl"
  }

  graphics {
    # Not using 'spice' to keep using cockpit GUI with ease :)
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
