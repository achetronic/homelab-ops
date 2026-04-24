# Create all instances
resource "libvirt_domain" "instance" {
  for_each = var.instances

  name        = each.key
  memory      = each.value.memory
  memory_unit = "KiB"
  vcpu        = each.value.vcpu
  type        = "kvm"

  # -------------------------------------------------------------------------
  # EXPOSED CPU
  # Expose host CPU features to the guest for maximum performance.
  # -------------------------------------------------------------------------
  cpu = {
    mode = "host-passthrough"
  }

  # -------------------------------------------------------------------------
  # OS BOOT & FIRMWARE
  # OS boot configuration using UEFI (OVMF).
  # -------------------------------------------------------------------------
  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "pc-q35-8.2"
    firmware     = "efi"
    loader       = "/usr/share/OVMF/OVMF_CODE_4M.fd"
    boot_devices = [
      { dev = "hd" },
      { dev = "cdrom" },
    ]
  }

  # -------------------------------------------------------------------------
  # HARDWARE DEVICES
  # Hardware peripherals attached to the VM.
  # -------------------------------------------------------------------------
  devices = {

    # -------------------------------------------------------------------------
    # STORAGE (DISKS)
    # index 0: CDROM containing the Talos ISO for initial boot and installation.
    # index 1: Persistent qcow2 data disk where the actual OS and data reside.
    # -------------------------------------------------------------------------
    disks = [
      # CDROM (First boot ISO)
      {
        device    = "cdrom"
        read_only = true
        source = {
          file = { file = "${local.volume_pool_base_path}/${each.value.image}.iso" }
        }
        target = { dev = "hda", bus = "sata" }
      },
      # Data Disk
      {
        device = "disk"
        source = {
          volume = {
            pool   = libvirt_pool.volume_pool.name
            volume = libvirt_volume.instance_disk[each.key].name
          }
        }
        target = { dev = "sda", bus = "scsi" }
      },
    ]

    # -------------------------------------------------------------------------
    # NETWORK INTERFACES
    # Bridges the VM's virtual network adapters directly to the host's interfaces,
    # allowing the VM to be a first-class citizen on the physical network.
    # -------------------------------------------------------------------------
    interfaces = [
      for network in each.value.networks : {
        source = {
          direct = { dev = network.interface, mode = "bridge" }
        }
        mac   = { address = lower(network.mac) }
        model = { type = "virtio" }
      }
    ]

    # -------------------------------------------------------------------------
    # CONSOLE ACCESS (GRAPHICS)
    # Provides VNC access listening on localhost. Useful for debugging boot issues
    # via an SSH tunnel directly to the hypervisor.
    # -------------------------------------------------------------------------
    graphics = [{
      vnc = { auto_port = true, listen = "127.0.0.1" }
    }]

    # -------------------------------------------------------------------------
    # VIRTUAL GPU (VIDEOS)
    # Virtual VGA adapter required to actually render the output for the VNC server.
    # -------------------------------------------------------------------------
    videos = [{
      model = { type = "vga", vram = 16384, heads = 1, primary = "yes" }
    }]

    # -------------------------------------------------------------------------
    # USB PASS-THROUGH (HOSTDEVS)
    # Maps physical USB devices (like Zigbee dongles) plugged into the host
    # directly to the VM so it can control them natively.
    # -------------------------------------------------------------------------
    hostdevs = length(each.value.usb_hostdevs) == 0 ? null : [
      for hd in each.value.usb_hostdevs : {
        managed = true
        subsys_usb = {
          source = {
            vendor  = { id = hd.vendor_id }
            product = { id = hd.product_id }
          }
        }
      }
    ]
  }

  autostart = true

  # -------------------------------------------------------------------------
  # IGNORE CHANGES: Welcome to libvirt provider v0.9.x
  # This provider exposes the ENTIRE libvirt XML schema. Libvirt auto-generates
  # dozens of controllers, addresses, aliases, and defaults (like watchdogs,
  # memballoons, etc.) when the VM boots.
  # We ignore everything except the core infrastructure we explicitly care about.
  # -------------------------------------------------------------------------
  lifecycle {
    ignore_changes = [
      # General Runtime
      running,
      current_memory,
      current_memory_unit,
      vcpu_placement,
      resource,
      sec_label,

      # CPU, OS, and Power
      cpu.check,
      cpu.migratable,
      features,
      clock,
      on_poweroff,
      on_reboot,
      on_crash,
      os.nv_ram,
      os.firmware_info,
      os.loader_readonly,
      os.loader_secure,
      os.loader_type,

      # Auto-generated peripherals
      devices.emulator,
      devices.audios,
      devices.channels,
      devices.controllers,
      devices.inputs,
      devices.mem_balloon,
      devices.rngs,
      devices.serials,
      devices.watchdogs,
      devices.consoles,

      # Graphics & Video
      devices.videos[0].address,
      devices.videos[0].alias,
      devices.graphics[0].vnc.port,
      devices.graphics[0].vnc.listeners,

      # Disks
      devices.disks[0], # CDROM can change during OS install
      devices.disks[1].address,
      devices.disks[1].alias,
      devices.disks[1].backing_store,
      devices.disks[1].driver,
      devices.disks[1].read_only,
      devices.disks[1].shareable,
      devices.disks[1].source.index,
      devices.disks[1].wwn,

      # Network Interfaces (Supporting up to 3)
      devices.interfaces[0].source.null,
      devices.interfaces[0].target,
      devices.interfaces[0].alias,
      devices.interfaces[0].address,
      devices.interfaces[1].source.null,
      devices.interfaces[1].target,
      devices.interfaces[1].alias,
      devices.interfaces[1].address,
      devices.interfaces[2].source.null,
      devices.interfaces[2].target,
      devices.interfaces[2].alias,
      devices.interfaces[2].address,

      # USB Hostdevs (Supporting up to 3)
      devices.hostdevs[0].address,
      devices.hostdevs[0].alias,
      devices.hostdevs[0].subsys_usb.source.address,
      devices.hostdevs[1].address,
      devices.hostdevs[1].alias,
      devices.hostdevs[1].subsys_usb.source.address,
      devices.hostdevs[2].address,
      devices.hostdevs[2].alias,
      devices.hostdevs[2].subsys_usb.source.address,
    ]
  }
}
