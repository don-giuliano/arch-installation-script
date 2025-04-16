#!/bin/bash

# Définir quelques couleurs pour le texte  
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Pas de couleur

echo -e "${GREEN}Bienvenue dans le script d'installation d'Arch Linux !${NC}"

# Vérification de la connexion internet  
echo -e "${GREEN}Vérification de la connexion internet...${NC}"
ping -c 1 archlinux.org &> /dev/null  
if [ $? -ne 0 ]; then  
    echo -e "${RED}Aucune connexion internet détectée ! Veuillez vérifier votre connexion.${NC}"
    exit 1  
fi

# Choix du clavier  
echo -e "${GREEN}Choix du layout de clavier (par défaut : us) :${NC}"
read -p "Entrez le layout (par exemple, 'us', 'fr', etc.) : " keyboard_layout  
loadkeys $keyboard_layout

# Partitionnement du disque  
echo -e "${GREEN}Partitionnement du disque...${NC}"
lsblk  
read -p "Quel disque souhaitez-vous partitionner ? (ex: /dev/sda) : " disk  
gdisk $disk

# Formatage des partitions  
echo -e "${GREEN}Formatage des partitions...${NC}"
read -p "Quelle partition souhaitez-vous formater ? (ex: /dev/sda1) : " partition  
mkfs.ext4 $partition

# Montage des partitions  
echo -e "${GREEN}Montage des partitions...${NC}"
mount $partition /mnt

# Installation de base  
echo -e "${GREEN}Installation du système de base...${NC}"
pacstrap /mnt base linux linux-firmware

# Configuration du système  
echo -e "${GREEN}Configuration du système...${NC}"
genfstab -U /mnt >> /mnt/etc/fstab  
arch-chroot /mnt /bin/bash <<EOF  
echo "Bienvenue sur votre nouvel Arch Linux !"

# Configuration locale  
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen  
locale-gen  
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf  

# Réseau  
echo "hostname_name" >> /etc/hostname  
# Configuration du réseau  
EOF

# Installation du bootloader  
echo -e "${GREEN}Installation du bootloader...${NC}"
read -p "Vous utilisez GRUB ? (y/n) : " grub_choice  
if [ "$grub_choice" = "y" ]; then  
    arch-chroot /mnt /bin/bash <<EOF  
pacman -S grub  
grub-install --target=i386-pc /dev/sda  
grub-mkconfig -o /boot/grub/grub.cfg  
EOF  
fi

# Finalisation  
echo -e "${GREEN}Installation terminée ! Redémarrez votre système.${NC}"

