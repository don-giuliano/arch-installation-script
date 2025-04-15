#!/bin/sh

# Mise à jour des paquets
echo "Mise à jour des paquets..."
sudo pacman -Syu || { echo "Erreur lors de la mise à jour des paquets." ; exit 1; }

# Configuration de pacman

sudo sed -i 's/^#Color$/Color/' '/etc/pacman.conf'
sudo sed -i 's/^#\(ParallelDownloads.*\)/\1\nILoveCandy/' '/etc/pacman.conf'
sudo sed -i 's/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j\$(nproc)\"/' /etc/makepkg.conf

# Installation du dépot Chaotic-AUR

sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com

sudo pacman-key --lsign-key 3056513887B78AEB

sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'

sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

sed -i '102 s/$/[chaotic-aur]/' /etc/pacman.conf

sed -i '103 s/$/Include = /etc/pacman.d/chaotic-mirrorlist/' /etc/pacman.conf

# Mise à jour des paquets
echo "Mise à jour des paquets..."
sudo pacman -Syu || { echo "Erreur lors de la mise à jour des paquets." ; exit 1; }

# Installation des firmwares

sudo pacman -S fwupd

# Installation des polices

sudo pacman -S ttf-dejavu ttf-liberation ttf-meslo-nerd noto-fonts-emoji adobe-source-code-pro-fonts otf-font-awesome ttf-droid

# Archivage et compression

sudo pacman -S ark zip unzip p7zip

# Système de fichier

sudo pacman -S ntfs-3g exfatprogs btrfs-progs e2fsprogs xfsprogs f2fs-tools udftools dosfstools

# Installation des codecs audios

sudo pacman -S flac wavpack a52dec lame libdca libmad libmpcdec opus libvorbis faac faad2 libfdk-aac opencore-amr speex

# Installation des codecs vidéos

sudo pacman -S aom david rav1e svt-av1 schroedinger libdv x264 x265 libmpeg2 xvidcore libtheora libvpx

# Installation des codecs d'image

sudo pacman -S jasper openjpeg libwebp libavif libheif perl-image-exiftool qt6-imageformats ffmpegthumbnailer

# Installation du serveur graphique

sudo pacman -S wayland

# Installation de l'environnement de bureau

sudo pacman -S plasma-desktop bluedevil breeze-gtk discover kde-gtk-config kdeplasma-addons kgamma kinfocenter kscreen ksshaskpass kwallet-pam kwrited ocean-sound-theme plasma-browser-integration plasma-disks plasma-firewall plasma-nm plasma-pa plasma-systemmonitor plasma-thunderbolt plasma-vault plasma-welcome plasma-workspace-wallpapers powerdevil print-manager sddm sddm-kcm spectacle wacomtablet xdg-desktop-portal-kde

# Installation du pare-feu

sudo pacman -S ufw gufw

# Installation du navigateur web

sudo pacman -S firefox firefox-i18n-fr

# Installation des applications de bureau

sudo pacman -S isoimagewriter kolourpaint gwenview gnome-disk-utility keepassxc kdenlive obs-studio tenacity

# Installation bureautique

sudo pacman -S libreoffice-fresh libreoffice-fresh-fr hunspell-fr

sudo systemctl enable sddm
sudo systemctl start sddm

exit 0
