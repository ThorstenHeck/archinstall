#!/bin/bash
EFI_MOUNTPOINT="/boot"
ROOT_MOUNTPOINT="/dev/sda1"
BOOT_MOUNTPOINT="/dev/sda"
MOUNTPOINT="/mnt"
EDITOR="nano"
# Variable für Formatierung
device=`lsblk -do name,tran | grep 'sd\|hd\|vd\|nvme\|mmcblk' | grep -v 'usb' | awk '{print "/dev/" $1}'`
BOOT_MOUNTPOINT=$device
ram=`free -t -m | grep 'Mem:' | awk '{print $2}'`
swap=$((ram * 2))
swapsect=$((swap * 2048))
# Festplatten Formatierung
sgdisk -og $device                                                  # Erase all GPT and create a GPT; Convert MBR to GPT
sgdisk -n 1:2048:1050623 -c 1:"EFI System Partition" -t 1:ef00 $device  # Neue Partition von 2048 bis 1050623 (+512MiB) in ef00 für UEFI
sectorstart=`sgdisk -F $device` # Variable für den ersten benutzbaren Sektor
sgdisk -n 2:$sectorstart:$swapsect -c 2:"Swap Partition" -t 2:8200 $device # Swap Partition erstellen
sectorstart=`sgdisk -F $device`
sectorend=`sgdisk -E $device`
sgdisk -n 3:$sectorstart:$sectorend -c 3:"Root" -t 3:8300 $device
# Systemupdate
pacman -Sy
# Mirrorlist
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
pacman -S reflector
reflector --verbose --country 'Germany' --latest 10 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
# Deklarieren der Variablen für das anlegen der Dateisysteme
partuefi=`lsblk -no name,partlabel | grep 'EFI System Partition' | awk '{print $1}' | sed 's/^..//' | awk '{print "/dev/" $1}'`
partroot=`lsblk -no name,partlabel | grep 'Root' | awk '{print $1}' | sed 's/^..//' | awk '{print "/dev/" $1}'`
partswap=`lsblk -no name,partlabel | grep 'Swap Partition' | awk '{print $1}' | sed 's/^..//' | awk '{print "/dev/" $1}'`
# uefi
mkfs.fat -F 32 -n EFIBOOT $partuefi
# root
mkfs.ext4 -L p_arch $partroot
# swap
mkswap -L p_swap $partswap
# Partitionen einhängen
mount -L p_arch /mnt  
mkdir -p /mnt/boot  
mount -L EFIBOOT /mnt/boot  
swapon -L p_swap 
