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
