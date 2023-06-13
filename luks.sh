#!/bin/bash
MOUNTPOINT="/mnt"
DEVICE=$(lsblk -n -do name,tran | grep -v 'loop' | grep -v 'usb' | awk '{print "/dev/" $1}')
sgdisk -og $DEVICE
sgdisk -n 1:2048:1050623 -c 1:"EFI System Partition" -t 1:ef00 $DEVICE
SECTORSTART=$(sgdisk -F $DEVICE)
SECTOREND=$(sgdisk -E $DEVICE)
sgdisk -n 2:$SECTORSTART:$SECTOREND -c 2:"Root" -t 2:8E00 $DEVICE
sleep 2
PARTUEFI=$(lsblk -no name,partlabel | grep 'EFI System Partition' | sed 's/^..//' | awk '{print "/dev/" $1}')
PARTROOT=$(lsblk -no name,partlabel | grep 'Root' | sed 's/^..//' | awk '{print "/dev/" $1}')

mkdir -p /root/luks
ssh-keygen -t ed25519 -f /root/luks/luks.key -q -N ""
chmod 0400 /root/luks/luks.key
chown root:root /root/luks/luks.key
cryptsetup luksFormat $PARTROOT --key-file /root/luks/luks.key --batch-mode
cryptsetup open --type luks $PARTROOT main_part --key-file /root/luks/luks.key
pvcreate /dev/mapper/main_part
vgcreate main_group /dev/mapper/main_part
lvcreate -L32G main_group -n swap
lvcreate -L64G main_group -n root
lvcreate -l 100%FREE main_group -n home
mkfs.ext4 /dev/mapper/main_group-root
mkfs.ext4 /dev/mapper/main_group-home
mkswap /dev/mapper/main_group-swap
mount /dev/mapper/main_group-root ${MOUNTPOINT}
mkdir -p ${MOUNTPOINT}/home
mount /dev/mapper/main_group-home ${MOUNTPOINT}/home
swapon /dev/mapper/main_group-swap
mkdir -p ${MOUNTPOINT}/boot
mount $PARTUEFI ${MOUNTPOINT}/boot
mkdir -p ${MOUNTPOINT}/luks
touch ${MOUNTPOINT}/luks/luks.key
mount --bind /root/luks/luks.key ${MOUNTPOINT}/luks

pacman -Sy --noconfirm
pacman -S reflector --noconfirm
reflector --verbose --country 'Germany' --latest 10 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist

pacstrap -K $MOUNTPOINT base base-devel linux linux-firmware netctl
genfstab -U $MOUNTPOINT > ${MOUNTPOINT}/etc/fstab

HOSTNAME='archlinux'
ZONE='Europe'
SUBZONE='Berlin'
KEYMAP='de-latin1'
LANG='de_DE.UTF-8'

arch-chroot $MOUNTPOINT ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
arch-chroot $MOUNTPOINT sh -c 'echo "archlinux" > /etc/hostname'
arch-chroot $MOUNTPOINT sh -c 'echo "LANG=de_DE.UTF-8" > /etc/locale.conf'
arch-chroot $MOUNTPOINT sh -c 'echo "KEYMAP=de-latin1" > /etc/vconsole.conf'

arch-chroot $MOUNTPOINT sed -i 's/#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
arch-chroot $MOUNTPOINT sed -i 's/#de_DE ISO-8859-1/de_DE ISO-8859-1/' /etc/locale.gen
arch-chroot $MOUNTPOINT sed -i 's/#de_DE@euro ISO-8859-15/de_DE@euro ISO-8859-15/' /etc/locale.gen
arch-chroot $MOUNTPOINT locale-gen

arch-chroot $MOUNTPOINT pacman -S wpa_supplicant networkmanager network-manager-applet dialog
arch-chroot $MOUNTPOINT sh -c 'curl https://raw.githubusercontent.com/ThorstenHeck/archinstall/master/pacman.conf > /etc/pacman.conf'
arch-chroot $MOUNTPOINT sh -c 'curl https://raw.githubusercontent.com/ThorstenHeck/archinstall/master/loader.conf > /boot/loader/loader.conf
arch-chroot $MOUNTPOINT sh -c 'curl https://raw.githubusercontent.com/ThorstenHeck/archinstall/master/arcch.conf > /boot/loader/entries/arch.conf'
arch-chroot $MOUNTPOINT sed -i 's/HOOKS.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefront block encrypt lvm2 filesystems fsck)/ig' /etc/mkinitcpio.conf

# arch-chroot $MOUNTPOINT pacman -Sy intel-ucode
# arch-chroot $MOUNTPOINT pacman -S linux-headers linux-lts linux-lts-headers
# arch-chroot $MOUNTPOINT pacman -S vim git

# arch-chroot $MOUNTPOINT mkinitcpio -p linux
# arch-chroot $MOUNTPOINT mkinitcpio -p linux-lts
# arch-chroot $MOUNTPOINT bootctl --path=/boot/ install

# ## sed REPLACE_ME...

# arch-chroot $MOUNTPOINT echo "root:initpw" | chpasswd

# swapoff -a
# umount -R $MOUNTPOINT
