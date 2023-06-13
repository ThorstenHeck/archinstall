#!/bin/bash
MOUNTPOINT="/mnt"
DEVICE=$(lsblk -n -do name,tran | grep -v 'loop' | grep -v 'usb' | awk '{print "/dev/" $1}')
RAM=$(free -t -m | grep 'Mem:' | awk '{print $2}')
SWAP=$((RAM * 2))
SWAPSECT=$((swap * 2048))
sgdisk -og $DEVICE
sgdisk -n 1:2048:1050623 -c 1:"EFI System Partition" -t 1:ef00 $DEVICE
SECTORSTART=$(sgdisk -F $DEVICE)
sgdisk -n 2:$SECTORSTART:$SWAPSECT -c 2:"Swap Partition" -t 2:8200 $DEVICE
SECTORSTART=$(sgdisk -F $DEVICE)
SECTOREND=$(sgdisk -E $DEVICE)
sgdisk -n 3:$SECTORSTART:$SECTOREND -c 3:"Root" -t 3:8300 $DEVICE

PARTUEFI=$(lsblk -no name,partlabel | grep 'EFI System Partition' | sed 's/^..//' | awk '{print "/dev/" $1}')
PARTROOT=$(lsblk -no name,partlabel | grep 'Root' | sed 's/^..//' | awk '{print "/dev/" $1}')
PARTSWAP=$(lsblk -no name,partlabel | grep 'Swap Partition' | sed 's/^..//' | awk '{print "/dev/" $1}')
echo $PARTUEFI
echo $PARTROOT
echo $PARTSWAP
#mkfs.fat -F 32 -n EFIBOOT $PARTUEFI
#yes | mkfs.ext4 -L p_arch $PARTROOT
#mkswap -L p_swap $PARTSWAP
#mount -L p_arch $MOUNTPOINT  
#mkdir -p ${MOUNTPOINT}/boot  
#mount -L EFIBOOT ${MOUNTPOINT}/boot
#swapon -L p_swap 
