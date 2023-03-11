# Install OS into SSD on Odroid M1

## Installation

### Pre-steps

* Connect the SBC to the network using an ethernet wire
* Connect the SPC to the power supply

### Actually install the OS

* Enter into menu 'Exit to shell' and execute the following commands:

```console
udhcpc
netboot_default
exit
```

* A new menu will appear in Petitboot. Just select the OS wanted and hit enter on your keyboard 

## FAQ:

### Bootloader does not autostart Linux and throw 'Default boot cancelled':

This is not documented anywhere. Your Petitboot is recognizing your USB keyboard/mouse as a boot device.
Just disconnect it and reboot the SPC.

### Where can I find the images to flash

These methods are not documented at all, so use them at your own risk. This is more like a links collection

* Raw images can be found here: http://ppa.linuxfactory.or.kr/images/raw/arm64/jammy/
* Netinstall images can be found here: http://ppa.linuxfactory.or.kr/installer/ODROID-M1/
* Netboot (PXE) configuration can be found here: http://ppa.linuxfactory.or.kr/installer/pxeboot/ODROID-M1/netboot-odroidm1.cfg

### Netboot installation is not detecting properly my nvme

Some NVME drives are not fully compatible with the controllers included in some Ubuntu modified versions by
hardkernel. Something I discovered is that Ubuntu 22.04 was not detecting the full size of one of my drives, but 
Ubuntu 20.04 was. So install the old one and upgrade it

```console
sudo su

apt update
apt upgrade
do-release-upgrade
```

### How to update the Kernel to newer versions

Once you have your system up-to-date, it's interesting to upgrade the kernel to newer versions to have some features
related to sensors, etc. 

```console
sudo su

apt search odroid-arm64
apt install <insert-your-versioned-package-here>
flash-kernel
update-initramfs -u
```