#!/bin/bash
MOUNTPOINT="/mnt"

pacman -Sy --noconfirm
pacman -S reflector --noconfirm
reflector --verbose --country 'Germany' --latest 10 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist

pacstrap -K $MOUNTPOINT base base-devel linux linux-firmware netctl
genfstab -U $MOUNTPOINT > ${MOUNTPOINT}/etc/fstab

arch-chroot $MOUNTPOINT pacman -S lvm2 --noconfirm

arch-chroot $MOUNTPOINT ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
arch-chroot $MOUNTPOINT sh -c 'echo "archlinux" > /etc/hostname'
arch-chroot $MOUNTPOINT sh -c 'echo "LANG=de_DE.UTF-8" > /etc/locale.conf'
arch-chroot $MOUNTPOINT sh -c 'echo "KEYMAP=de-latin1" > /etc/vconsole.conf'

arch-chroot $MOUNTPOINT sed -i 's/#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
arch-chroot $MOUNTPOINT sed -i 's/#de_DE ISO-8859-1/de_DE ISO-8859-1/' /etc/locale.gen
arch-chroot $MOUNTPOINT sed -i 's/#de_DE@euro ISO-8859-15/de_DE@euro ISO-8859-15/' /etc/locale.gen
arch-chroot $MOUNTPOINT locale-gen

arch-chroot $MOUNTPOINT ln -s /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d
arch-chroot $MOUNTPOINT ln -s /etc/fonts/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d
arch-chroot $MOUNTPOINT ln -s /etc/fonts/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d
    
arch-chroot $MOUNTPOINT sh -c 'curl https://raw.githubusercontent.com/ThorstenHeck/archinstall/master/local.conf > /etc/fonts/local.conf'
arch-chroot $MOUNTPOINT sh -c 'curl https://raw.githubusercontent.com/ThorstenHeck/archinstall/master/pacman.conf > /etc/pacman.conf'
arch-chroot $MOUNTPOINT sed -i 's/^HOOKS.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)/ig' /etc/mkinitcpio.conf

arch-chroot $MOUNTPOINT pacman -S wpa_supplicant networkmanager network-manager-applet dialog ttf-dejavu ttf-liberation noto-fonts --noconfirm
arch-chroot $MOUNTPOINT pacman -Sy intel-ucode --noconfirm
arch-chroot $MOUNTPOINT pacman -S linux-headers linux-lts linux-lts-headers --noconfirm
arch-chroot $MOUNTPOINT pacman -S vim git --noconfirm

arch-chroot $MOUNTPOINT mkinitcpio -p linux
arch-chroot $MOUNTPOINT mkinitcpio -p linux-lts
arch-chroot $MOUNTPOINT bootctl --path=/boot/ install
arch-chroot $MOUNTPOINT sh -c 'curl https://raw.githubusercontent.com/ThorstenHeck/archinstall/master/loader.conf > /boot/loader/loader.conf'
arch-chroot $MOUNTPOINT sh -c 'curl https://raw.githubusercontent.com/ThorstenHeck/archinstall/master/arch.conf > /boot/loader/entries/arch.conf'
arch-chroot $MOUNTPOINT sh -c " UUID=$(blkid | grep Root | cut -d"=" -f 2 | cut -c-36 | tr -d '\"') ; echo options cryptdevice=UUID=\${UUID}:cryptlvm root=/dev/mapper/main_group-root quiet rw >> /boot/loader/entries/arch.conf"

arch-chroot $MOUNTPOINT echo "root:initpw" | chpasswd

# swapoff -a
# umount -R $MOUNTPOINT
