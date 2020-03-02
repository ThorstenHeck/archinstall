#!/bin/bash
EFI_MOUNTPOINT="/boot"
ROOT_MOUNTPOINT="/dev/sda1"
BOOT_MOUNTPOINT="/dev/sda"
MOUNTPOINT="/mnt"
EDITOR="nano"
device=`lsblk -do name,tran | grep 'sd\|hd\|vd\|nvme\|mmcblk' | grep -v 'usb' | awk '{print "/dev/" $1}'`
BOOT_MOUNTPOINT=$device
ram=`free -t -m | grep 'Mem:' | awk '{print $2}'`
swap=$((ram * 2))
swapsect=$((swap * 2048))
sgdisk -og $device
sgdisk -n 1:2048:1050623 -c 1:"EFI System Partition" -t 1:ef00 $device
sectorstart=`sgdisk -F $device
sgdisk -n 2:$sectorstart:$swapsect -c 2:"Swap Partition" -t 2:8200 $device
sectorstart=`sgdisk -F $device`
sectorend=`sgdisk -E $device`
sgdisk -n 3:$sectorstart:$sectorend -c 3:"Root" -t 3:8300 $device
pacman -Sy --noconfirm
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
pacman -S reflector --noconfirm
reflector --verbose --country 'Germany' --latest 10 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
partuefi=`lsblk -no name,partlabel | grep 'EFI System Partition' | awk '{print $1}' | sed 's/^..//' | awk '{print "/dev/" $1}'`
partroot=`lsblk -no name,partlabel | grep 'Root' | awk '{print $1}' | sed 's/^..//' | awk '{print "/dev/" $1}'`
partswap=`lsblk -no name,partlabel | grep 'Swap Partition' | awk '{print $1}' | sed 's/^..//' | awk '{print "/dev/" $1}'`
mkfs.fat -F 32 -n EFIBOOT $partuefi
y | mkfs.ext4 -L p_arch $partroot
mkswap -L p_swap $partswap
mount -L p_arch /mnt  
mkdir -p /mnt/boot  
mount -L EFIBOOT /mnt/boot  
swapon -L p_swap 
pacstrap $MOUNTPOINT base base-devel linux linux-firmware nano
genfstab -Up $MOUNTPOINT > /mnt/etc/fstab
echo "KEYMAP=$KEYMAP" > ${MOUNTPOINT}/etc/vconsole.conf
host_name='archlinux'
echo $host_name > /etc/hostname
ZONE='Europe'
SUBZONE='Berlin'
arch-chroot /mnt/ ln -sf /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime
echo LANG=de_DE.UTF-8 > /etc/locale.conf
arch-chroot /mnt/ sed -i 's/#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
arch-chroot /mnt/ sed -i 's/#de_DE ISO-8859-1/de_DE ISO-8859-1/' /etc/locale.gen
arch-chroot /mnt/ sed -i 's/#de_DE@euro ISO-8859-15/de_DE@euro ISO-8859-15/' /etc/locale.gen
arch-chroot /mnt/ locale-gen
pacman -Sy
arch-chroot /mnt/ mkinitcpio -p linux
pacman --root $MOUNTPOINT -S efibootmgr dosfstools gptfdisk grub --noconfirm
arch-chroot /mnt/ grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub --recheck --debug
arch-chroot /mnt/ grub-mkconfig -o /boot/grub/grub.cfg

umount_partitions(){
  mounted_partitions=(`lsblk | grep '/mnt' | awk '{print $7}' | sort -r`)
  swapoff -a
  for i in "${mounted_partitions[@]}"; do
    umount $i
  done
}
umount_partitions
