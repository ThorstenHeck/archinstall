# Arch Linux install Script

Da ich nun einige male Arch neu aufgesetzt haben, würde ich mich mal gerne an einen Automatismus zum installieren von Arch wagen.  

## Installation

curl https://raw.githubusercontent.com/ThorstenHeck/archinstall/master/archinstallshell2.sh | bash  

## Warnung

Die gesamte Festplatte wird durch den Vorgang gelöscht!!!  
Nur zu Testzwecken benutzen.   

Readme.md und tatsächliches Shell Script haben Abweichungen. die Readme Datei dient aber grundsätzlich als Erklärung der einzelnen Befehle.  

## Partitions Schema

Das Partitions Schema soll statisch bleiben.  
Da wir zunächst nur Laptops aufsetzen, erstellen wir ein Partitions Schema mit folgenden Eigenschaften:  

|/dev/sdx1|/dev/sdx2|/dev/sdx3|
|----------|----------|----------|
|UEFI|Root|Swap|
|ef00|8300|8200|
|512MiB|+max|x2 RAM - max 32GiB|

Auf Basis dessen wird jeder Rechner Partitioniert.  

## System Konfiguration

1. "Shebang Line" #!/bin/bash  
2. Keymap
3. Default Editor
4. Mirrorlist
5. Partition Schema
6. Partition Format
7. Install Base System
8. WLAN Konfiguration


## Manuelle Konfiguration:  

### Loadkeys

loadkeys de-latiin1

### Wifi

Etablieren einer Wifi Verbindung über  

wifi-menu  

## Automatische Konfiguration

Deklarieren der Variable MOUNTPOINT zu "/mnt".  

```Bash
# MOUNTPOINTS
    EFI_MOUNTPOINT="/boot"
    ROOT_MOUNTPOINT="/dev/sda1"
    BOOT_MOUNTPOINT="/dev/sda"
    MOUNTPOINT="/mnt"
```
Deklarieren der Editor Variable zu nano.  
```Bash
# Editor
    EDITOR="nano"
```

Mirrorlist mithilfe von Reflector konfigurieren.  

```Bash
# Mirrorlist
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
    pacman -S reflector
    reflector --verbose --country 'Germany' --latest 10 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```

Systemupdate  

```Bash
# Systemupdate
    pacman -Sy
```
Basisinstallation:  
```Bash
# Basisinstallation
    pacstrap $MOUNTPOINT base base-devel linux linux-firmware nano
```

Formatieren der Partitionen nach den vorher gesetzten "partlabel".  

```Bash
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
```

```Bash
# Konfiguration Keymap
echo "KEYMAP=$KEYMAP" > ${MOUNTPOINT}/etc/vconsole.conf

# genfstab
genfstab -Up $MOUNTPOINT > /mnt/etc/fstab 

# hostname
host_name='archlinux'
echo $host_name > ${MOUNTPOINT}/etc/hostname
arch_chroot "sed -i '/127.0.0.1/s/$/ '${host_name}'/' /etc/hosts"
arch_chroot "sed -i '/::1/s/$/ '${host_name}'/' /etc/hosts"

# timezone
ZONE='Europe'
SUBZONE='Berlin'
arch_chroot "ln -sf /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime"
arch_chroot "sed -i '/#NTP=/d' /etc/systemd/timesyncd.conf"
arch_chroot "sed -i 's/#Fallback//' /etc/systemd/timesyncd.conf"
arch_chroot "echo \"FallbackNTP=0.pool.ntp.org 1.pool.ntp.org 0.fr.pool.ntp.org\" >> /etc/systemd/timesyncd.conf"
arch_chroot "systemctl enable systemd-timesyncd.service"

# Systemkonfiguration
echo LANG=de_DE.UTF-8 > /etc/locale.conf
arch_chroot "sed -i 's/#\('${LOCALE_UTF8}'\)/\1/' /etc/locale.gen"

arch_chroot "sed -i 's/#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen"
arch_chroot "sed -i 's/#de_DE ISO-8859-1/de_DE ISO-8859-1/' /etc/locale.gen"
arch_chroot "sed -i 's/#de_DE@euro ISO-8859-15/de_DE@euro ISO-8859-15/' /etc/locale.gen"
arch_chroot "locale-gen"

# Systemupdate
pacman -Sy
# mkinitcpio
arch_chroot "mkinitcpio -p linux"

```

```Bash
# Install Bootloader  
pacman --root $MOUNTPOINT -S efibootmgr dosfstools gptfdisk
# Konfiguration Bootloader
arch_chroot "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub --recheck --debug"
arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"

```


Funktion die alle Block Devices, die den Mountpoint "/mnt" besitzen wieder unmounten.  

```Bash
umount_partitions(){
  mounted_partitions=(`lsblk | grep ${MOUNTPOINT} | awk '{print $7}' | sort -r`)
  swapoff -a
  for i in ${mounted_partitions[@]}; do
    umount $i
  done
}
```

Holt sich das Gerät, welches sd, hd, vd, nvme oder mmcblk heißt und keine Slaves - Achtung klappt nur zuverlässig mit einer einzigen Festplatte ohne USB Sticks und speichert diesen in die Variable BOOT_MOUNTPOINT.  

```Bash
select_device(){
  device=(`lsblk -d | awk '{print "/dev/" $1}' | grep 'sd\|hd\|vd\|nvme\|mmcblk'`)
  BOOT_MOUNTPOINT=$device
}
```

Update: Kann nun auch USB Geräte unterscheiden:  

```Bash
select_device(){
  device=`lsblk -do name,tran | grep 'sd\|hd\|vd\|nvme\|mmcblk' | grep -v 'usb' | awk '{print "/dev/" $1}'`
  BOOT_MOUNTPOINT=$device
}
```

Anschließend wollen wir mit gdisk die Partitionierung vorhnehmen - da wir dies aber automatisch vornehmen wollen, nutzen wir sgdisk um das ganze unbeaufsichtigt innerhalb eines Shell Scripts zu nutzen:  

Dazu benötigen wir zusätzlich noch die Anzahl des gesamten RAMs in Bytes:  

```Bash
get_ram(){
ram=`free -t -m | grep 'Mem:' | awk '{print $2}'`
swap=$((ram * 2))
swapsect=$((swap * 2048))
} 
```

```Bash
#!/bin/bash
sgdisk -og $device                                                  # Erase all GPT and create a GPT; Convert MBR to GPT
sgdisk -n 1:2048:1050623 -c 1:"EFI System Partition" -t 1:ef00 $device  # Neue Partition von 2048 bis 1050623 (+512MiB) in ef00 für UEFI
sectorstart=`sgdisk -F $device` # Variable für den ersten benutzbaren Sektor
sgdisk -n 2:$sectorstart:$swapsect -c 2:"Swap Partition" -t 2:8200 $device # Swap Partition erstellen
sectorstart=`sgdisk -F $device`
sectorend=`sgdisk -E $device`
sgdisk -n 3:$sectorstart:$sectorend -c 3:"Root" -t 3:8300 $device
```

## WLAN Konfiguration

Erstellen eines netctl Profils  

```Bash
#!/bin/bash
wlan=`iw dev | grep 'Interface' | awk '{print $2}'`
SSID=QualQuappenLiebhaber01
netctlprofile=$wlan-$SSID
touch /etc/netctl/$netctlprofile
echo Description='Automatically generated profile' >> /etc/netctl/$netctlprofile
echo Interface=$wlan >> /etc/netctl/$netctlprofile
echo Security=wpa >> /etc/netctl/$netctlprofile
echo ESSID=$SSID >> /etc/netctl/$netctlprofile
echo IP=dhcp >> /etc/netctl/$netctlprofile
echo Key=SECRET >> /etc/netctl/$netctlprofile
```

Pfad: /etc/netctl/wlan0-QualQuappenLiebhaber01  
```Bash
Description='Automatically generated profile'
Interface=wlan0
Connection=wireless
Security=wpa
ESSID=SECRET
IP=dhcp
Key=SECRET
```
