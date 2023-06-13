#!/bin/bash
MOUNTPOINT="/mnt"
DEVICE=$(lsblk -n -do name,tran | grep -v 'loop' | grep -v 'usb' | awk '{print "/dev/" $1}')
RAM=$(free -t -m | grep 'Mem:' | awk '{print $2}')
SWAP=$((RAM * 2))
SWAPSECT=$((SWAP * 2048))
sgdisk -og $DEVICE
sgdisk -n 1:2048:1050623 -c 1:"EFI System Partition" -t 1:ef00 $DEVICE
SECTORSTART=$(sgdisk -F $DEVICE)
sgdisk -n 2:$SECTORSTART:$SWAPSECT -c 2:"Swap Partition" -t 2:8200 $DEVICE
SECTORSTART=$(sgdisk -F $DEVICE)
SECTOREND=$(sgdisk -E $DEVICE)
sgdisk -n 3:$SECTORSTART:$SECTOREND -c 3:"Root" -t 3:8300 $DEVICE
sleep 2
PARTUEFI=$(lsblk -no name,partlabel | grep 'EFI System Partition' | sed 's/^..//' | awk '{print "/dev/" $1}')
PARTROOT=$(lsblk -no name,partlabel | grep 'Root' | sed 's/^..//' | awk '{print "/dev/" $1}')
PARTSWAP=$(lsblk -no name,partlabel | grep 'Swap Partition' | sed 's/^..//' | awk '{print "/dev/" $1}')
mkfs.fat -F 32 -n EFIBOOT $PARTUEFI
yes | mkfs.ext4 -L p_arch $PARTROOT
mkswap -L p_swap $PARTSWAP
mount -L p_arch $MOUNTPOINT  
mkdir -p ${MOUNTPOINT}/boot  
mount -L EFIBOOT ${MOUNTPOINT}/boot
swapon -L p_swap 

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

arch-chroot $MOUNTPOINT ln -sf /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime
arch-chroot $MOUNTPOINT echo $HOSTNAME > /etc/hostname
arch-chroot $MOUNTPOINT echo LANG=$LANG > /etc/locale.conf
arch-chroot $MOUNTPOINT echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

arch-chroot $MOUNTPOINT sed -i 's/#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
arch-chroot $MOUNTPOINT sed -i 's/#de_DE ISO-8859-1/de_DE ISO-8859-1/' /etc/locale.gen
arch-chroot $MOUNTPOINT sed -i 's/#de_DE@euro ISO-8859-15/de_DE@euro ISO-8859-15/' /etc/locale.gen
arch-chroot $MOUNTPOINT locale-gen
arch-chroot $MOUNTPOINT mkinitcpio -p linux
pacman --root $MOUNTPOINT -S efibootmgr dosfstools gptfdisk grub --noconfirm
arch-chroot $MOUNTPOINT grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub --recheck --debug
arch-chroot $MOUNTPOINT grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot $MOUNTPOINT echo "root:initpw" | chpasswd

swapoff -a
umount -R $MOUNTPOINT
