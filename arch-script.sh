#!/bin/sh

# Définir quelques couleurs pour le texte  
LIGHT_BLUE='\033[1;34m' # Un bleu clair  
RED='\033[0;31m'
NC='\033[0m' # Pas de couleur

echo -e "${LIGHT_BLUE}Bienvenue dans le script d'installation d'Arch Linux !${NC}"

# Vérification de la connexion internet  
echo -e "${LIGHT_BLUE}Vérification de la connexion internet...${NC}"
ping -c 1 archlinux.org > /dev/null 2>&1  
if [ $? -ne 0 ]; then  
    echo -e "${RED}Aucune connexion internet détectée ! Veuillez vérifier votre connexion.${NC}"
    exit 1  
fi

# Choix du clavier  
echo -e "${LIGHT_BLUE}Choix du layout de clavier (par défaut : us) :${NC}"
read -p "Entrez le layout (par exemple, 'us', 'fr', etc.) : " keyboard_layout  
loadkeys "$keyboard_layout"

# Affichage des disques disponibles avec un numéro  
echo -e "${LIGHT_BLUE}Disques disponibles :${NC}"
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

# Partitionnement automatique avec sfdisk  
echo -e "${LIGHT_BLUE}Création de partitions sur le disque $disk...${NC}"
(
echo ,,,   # Partition principale pour le système  
) | sfdisk "$disk" || { echo -e "${RED}Erreur lors de la création des partitions !${NC}"; exit 1; }

# Formatage de la partition principale  
partition="${disk}1"  # Normalement la première partition (système)  
echo -e "${LIGHT_BLUE}Formatage de la partition système $partition...${NC}"
mkfs.ext4 "$partition" || { echo -e "${RED}Erreur lors du formatage de la partition !${NC}"; exit 1; }

# Montage des partitions  
echo -e "${LIGHT_BLUE}Montage de la partition $partition...${NC}"
mount "$partition" /mnt || { echo -e "${RED}Erreur lors du montage de la partition !${NC}"; exit 1; }

# Installer zram  
echo -e "${LIGHT_BLUE}Configuration de zram pour le swap...${NC}"
if ! modprobe zram; then  
    echo -e "${RED}Erreur lors du chargement de zram !${NC}"
    exit 1  
fi

# Configurer zram  
echo -e "${LIGHT_BLUE}Création d'un swap zram de 2 Go...${NC}"
echo "lmk 2G" > /sys/block/zram0/disksize

# Formater zram  
if ! mkswap /dev/zram0; then  
    echo -e "${RED}Erreur lors du formatage du swap zram !${NC}"
    exit 1  
fi

# Activer zram  
if ! swapon /dev/zram0; then  
    echo -e "${RED}Erreur lors de l'activation du swap zram !${NC}"
    exit 1  
fi

# Installation de base  
echo -e "${LIGHT_BLUE}Installation du système de base...${NC}"
pacstrap /mnt base linux linux-firmware || { echo -e "${RED}Erreur lors de l'installation de la base !${NC}"; exit 1; }

# Configuration du système  
echo -e "${LIGHT_BLUE}Configuration du système...${NC}"
genfstab -U /mnt >> /mnt/etc/fstab || { echo -e "${RED}Erreur lors de la génération de fstab !${NC}"; exit 1; }
arch-chroot /mnt /bin/sh <<EOF  
echo "Bienvenue sur votre nouvel Arch Linux !"
# Configuration locale  
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen  
locale-gen  
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf  
# Réseau  
echo "hostname_name" >> /etc/hostname  
EOF

# Installation du bootloader  
echo -e "${LIGHT_BLUE}Installation du bootloader...${NC}"
read -p "Vous utilisez GRUB ? (y/n) : " grub_choice  
if [ "$grub_choice" = "y" ]; then  
    arch-chroot /mnt /bin/sh <<EOF  
pacman -S grub  
grub-install --target=i386-pc /dev/sda  
grub-mkconfig -o /boot/grub/grub.cfg  
EOF  
fi

# Finalisation  
echo -e "${LIGHT_BLUE}Installation terminée ! Redémarrez votre système.${NC}"
