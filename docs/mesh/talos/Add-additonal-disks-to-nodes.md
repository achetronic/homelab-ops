# Add additional disks to Kubernetes nodes with Talos Linux


## Short introduction

This guide will show you how to add additional disks for storage on Talos Linux. This is useful when you want to expand the storage capabilities of your Kubernetes cluster, no matter which storage provisioner you're using.

{{< admonition tip >}}
You can do this before installing Talos, or if you have already installed it, do it with `talosctl edit machineconfig`.
{{< /admonition >}}

## Configuration

This configuration has to be done **only on the node where you are mounting the disk**.

The configuration will focus mostly on setting this up on a Raspberry Pi. If you are not doing this on a Raspberry Pi, you can just mount the disk and proceed with the configuration.

However, if you are doing it on a Raspberry Pi, you need to prepare the disk first:

* Connect the disk via USB to your machine.

* Check the name of the disk with:

  ```bash
  lsblk
  ```

* Now, you need to wipe the disk completely, including the partition table information on it:
  {{< admonition warning >}}
  Make sure you do a backup first if the disk is not empty. This will wipe it clean.
  {{< /admonition >}}

  ```bash
  sudo wipefs -a /dev/sdX
  ```

* Now, you need to create a partition of type `XFS` before proceeding. We will use `gparted` for this:

  1. Install `gparted`

     ```bash
     # Debian based systems
     sudo apt install gparted

     # Arch based systems
     sudo pacman -S gparted
     ```

  2. Open `gparted`, select the disk from the dropdown in the top right.

  3. In the menu, select `Device` -> `Create Partition Table` -> `Type GPT`.

  4. Then, select `Partition`.

  5. In the menu, leave everything as default, except `File system` -> `XFS`.

  6. Click apply and wait for the disk to get partitioned, then you can eject it from the machine.

* Plug the disk on the node you wish to configure, and proceed.

{{< admonition warning >}}
Take care where you are mounting the disk. Talos Linux expects it to be mounted in a directory under `/var/mnt`. If you mount it somewhere else, the configuration will not be successful.
{{< /admonition >}}

Here is the configuration (click to expand):

```yaml
machine:
  kubelet:
    extraMounts:
      - destination: /var/mnt/storage
        type: bind
        source: /var/mnt/storage
        options:
          - bind
          - rshared
          - rw

  disks:
      - device: /dev/sdX # The name of the disk to use.
        partitions:
          - mountpoint: /var/mnt/storage # Where to mount the partition.
```

# Ref: https://kubito.dev/page/3/
