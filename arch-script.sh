#!/bin/sh

# Définir quelques couleurs pour le texte  
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # Pas de couleur

echo -e "${BLUE}Bienvenue dans le script d'installation d'Arch Linux !${NC}"

# Vérification de la connexion internet  
echo -e "${BLUE}Vérification de la connexion internet...${NC}"
ping -c 1 archlinux.org > /dev/null 2>&1  
if [ $? -ne 0 ]; then  
    echo -e "${RED}Aucune connexion internet détectée ! Veuillez vérifier votre connexion.${NC}"
    exit 1  
fi

# Choix du clavier  
echo -e "${BLUE}Choix du layout de clavier (par défaut : us) :${NC}"
read -p "Entrez le layout (par exemple, 'us', 'fr', etc.) : " keyboard_layout  
loadkeys "$keyboard_layout"

# Affichage des disques disponibles avec un numéro  
echo -e "${BLUE}Disques disponibles :${NC}"
disks=$(lsblk -d -n -o NAME | awk '{print "/dev/"$1}')
i=1  
for disk in $disks; do  
    size=$(lsblk -d -n -o SIZE "$disk")
    echo "${i}: $disk ($size)"
    i=$((i + 1))
done

# Sélection du disque à partitionner  
while true; do  
    read -p "Choisissez le numéro du disque à partitionner : " disk_number  
    if [ "$disk_number" -ge 1 ] && [ "$disk_number" -le "$((i-1))" ]; then  
        disk=$(echo "$disks" | sed -n "${disk_number}p")
        break  
    else  
        echo -e "${RED}Numéro invalide. Veuillez réessayer.${NC}"
    fi  
done

# Partitionnement du disque  
echo -e "${BLUE}Partitionnement du disque $disk...${NC}"
gdisk "$disk"

# Formatage des partitions  
echo -e "${BLUE}Formatage des partitions...${NC}"
read -p "Quelle partition souhaitez-vous formater ? (ex: /dev/sda1) : " partition  
mkfs.ext4 "$partition"

# Montage des partitions  
echo -e "${BLUE}Montage des partitions...${NC}"
mount "$partition" /mnt

# Installation de base  
echo -e "${BLUE}Installation du système de base...${NC}"
pacstrap /mnt base linux linux-firmware

# Configuration du système  
echo -e "${BLUE}Configuration du système...${NC}"
genfstab -U /mnt >> /mnt/etc/fstab  
arch-chroot /mnt /bin/sh <<EOF  
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
echo -e "${BLUE}Installation du bootloader...${NC}"
read -p "Vous utilisez GRUB ? (y/n) : " grub_choice  
if [ "$grub_choice" = "y" ]; then  
    arch-chroot /mnt /bin/sh <<EOF  
pacman -S grub  
grub-install --target=i386-pc /dev/sda  
grub-mkconfig -o /boot/grub/grub.cfg  
EOF  
fi

# Finalisation  
echo -e "${BLUE}Installation terminée ! Redémarrez votre système.${NC}"
