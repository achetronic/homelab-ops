# Install Ubuntu Server into SSD on OrangePi 5

## Installation

### Pre-steps

The first thing before going forward is to have everything up-to-date (even firmware), so open the config CLI
executing the command `orangepi-config` 

Then go to `System > Firmware` and hit `<Yes>`. This will execute a bunch of commands, and after all the process, 
your system will be up-to-date

> This is similar to executing `apt update && apt upgrade` but for some reason, failing with the second
> commands in the first time you did it just after starting your new OS

Now it's time to install some tools that will be used later, executing the following command:

`apt install gdisk fdisk`

> I know, I know, parted is already included in the distro, but I prefer not to play with bombs and gdisk is easier

### Delete all the partitions on SPI flash memory

SPI flash memory is that place storing the bootloader, so what we want to do is deleting all the partitions there,
and then rebuild them (the last, later).

Get the path to the dev related to SPI executing `fdisk -l`. The device called something like `mtdblock0` and
with 16MB size is the right one. Probably you will get something like `/dev/mtdblock0`

After getting the device, delete all the partitions inside, entering into gdisk:

```console
sudo gdisk /dev/mtdblock0
```

After entering inside, write `p` and hit <enter> key. You will get a list of the partitions present into that device.
To delete them, write `d` + <enter>, then write the number of the partition and hit <enter> again. You will get the
following output

```console
Number  Start (sector)    End (sector)  Size       Code  Name
   1              64            7167   3.5 MiB     8300  idbloader
   2            7168            7679   256.0 KiB   8300  vnvm
   3            7680            8063   192.0 KiB   8300  reserved_space
   4            8064            8127   32.0 KiB    8300  reserved1
   5            8128            8191   32.0 KiB    8300  uboot_env
   6            8192           16383   4.0 MiB     8300  reserved2
   7           16384           32734   8.0 MiB     8300  uboot

Command (? for help): d
Partition number (1-7): 1

Command (? for help): d
Partition number (2-7): 2

Command (? for help): d
Partition number (3-7): 3

Command (? for help): d
Partition number (4-7): 4

Command (? for help): d
Partition number (5-7): 5

Command (? for help): d
Partition number (6-7): 6

Command (? for help): d
Using 7
```

> Don't forget about writing the changes into disk: `<w> + <Enter>`

### Delete all the partitions on the SSD drive

Repeat the previous steps, but for the device `/dev/nvme0n1`

### Reinstall the bootloader into SPI flash memory

Enter into config CLI with the command `orangepi-config`, 
and go to `System > Install (bootloader) > Install/Update the bootloader on SPI flash`.

Hit `<Yes>` and wait. After that process finish, your bootloader is ready to rock

### Copy the OS ISO into OrangePi

After flashing the bootloader, it's needed to transfer the ISO image into the OrangePi. No matter which method is used
(USB stick, SCP...) but personally I prefer to use SCP because the fastest one in terms of ease:

```console
scp ./Orangepi5_1.1.6_ubuntu_jammy_server_linux5.10.110.img root@192.168.2.31:/root/
```

### Flash the OS into the SSD

```console
cd /root

sudo dd bs=1M if=Orangepi5_1.1.6_ubuntu_jammy_server_linux5.10.110.img of=/dev/nvme0n1 status=progress
```

## FAQ:

### Where to find all the instructions:

Some fixes and steps are documented on my own, but some of them were extracted from the 
[following video](https://www.youtube.com/watch?v=cBqV4QWj0lE)

### MAC address keep changing every reboot:

A quick fix is fixing the MAC address on the connection settings

```console
sudo mv /etc/network/interfaces /etc/network/interfaces.bak

nano /etc/network/interfaces
```

```console
auto eth0
iface eth0 inet dhcp 
        hwaddress ether AA:BB:CC:DD:EE:FF
```

> Kudos to this random guy
> [for the fix](https://www.reddit.com/r/OrangePI/comments/14sleyi/comment/jqza65e/?utm_source=share&utm_medium=web2x&context=3)

### My router is not assigning the static IP to the MAC

This is because your DHCP session is not expired. To force your DHCP server to start another session for your
client, just drop the current session and ask for a new one

```console
# Drop the current lease
dhclient -r eth0

# Ask for some new DHCP lease
dhclient eth0
```

### I lost the ISO image. Where do I download it?

Just go to [downloads section](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-pi-5.html)
