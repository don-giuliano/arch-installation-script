#!/bin/sh

# Définir quelques couleurs pour le texte  
LIGHT_BLUE='\033[1;34m' # Un bleu clair  
RED='\033[0;31m'
NC='\033[0m' # Pas de couleur

# Affichage du message de bienvenue  
echo "---------------------------------------------------------------------------"
echo -e "${LIGHT_BLUE}Bienvenue dans le script d'installation d'Arch Linux !${NC}"
echo "---------------------------------------------------------------------------"

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

# Demander au choix d'utiliser le chiffrement LUKS  
read -p "Voulez-vous chiffrer le disque avec LUKS ? (y/n) : " encrypt_choice

# S'assurer que le disque n'est pas monté avant le partitionnement  
mounted_partitions=$(lsblk | grep "${disk}" | grep "mnt")
if [ -n "$mounted_partitions" ]; then  
    echo -e "${RED}Le disque $disk est actuellement monté, je vais le démonter...${NC}"
    umount "${disk}"* || { echo -e "${RED}Erreur lors du démontage des partitions sur $disk.${NC}"; exit 1; }
fi

# Menu pour le choix du type de partitionnement  
echo -e "${LIGHT_BLUE}Choix de la méthode de partitionnement :${NC}"
echo "1. Partitionnement automatique"
echo "2. Partitionnement avancé avec cfdisk"

while true; do  
    read -p "Sélectionnez une option (1 ou 2) : " partition_choice  
    if [ "$partition_choice" = "1" ]; then  
        # Partitionnement automatique  
        echo -e "${LIGHT_BLUE}Création de partitions sur le disque $disk...${NC}"
        (
            echo ,,,   # Partition principale pour le système  
        ) | sfdisk "$disk" || { echo -e "${RED}Erreur lors de la création des partitions !${NC}"; exit 1; }
        break  
    elif [ "$partition_choice" = "2" ]; then  
        # Partitionnement avancé avec cfdisk  
        echo -e "${LIGHT_BLUE}Lancement de cfdisk sur le disque $disk...${NC}"
        cfdisk "$disk" || { echo -e "${RED}Erreur lors de l'utilisation de cfdisk !${NC}"; exit 1; }
        break  
    else  
        echo -e "${RED}Choix invalide. Veuillez sélectionner 1 ou 2.${NC}"
    fi  
done

# Si LUKS est choisi, chiffrer la partition avec LUKS  
partition="${disk}1"  # Normalement la première partition (système)
if [ "$encrypt_choice" = "y" ]; then  
    echo -e "${LIGHT_BLUE}Chiffrement de la partition $partition avec LUKS...${NC}"
    cryptsetup luksFormat "$partition" || { echo -e "${RED}Erreur lors du chiffrement de la partition !${NC}"; exit 1; }

    # Ouvrir le volume chiffré  
    cryptsetup open "$partition" cryptroot || { echo -e "${RED}Erreur lors de l'ouverture du volume chiffré !${NC}"; exit 1; }
    partition="/dev/mapper/cryptroot" # Mise à jour de la partition à formater  
fi

# Formatage de la partition principale  
echo -e "${LIGHT_BLUE}Formatage de la partition système $partition...${NC}"
mkfs.ext4 "$partition" || { echo -e "${RED}Erreur lors du formatage de la partition !${NC}"; exit 1; }

# Montage des partitions  
echo -e "${LIGHT_BLUE}Montage de la partition $partition...${NC}"
mount "$partition" /mnt || { echo -e "${RED}Erreur lors du montage de la partition !${NC}"; exit 1; }

# Choix du type de swap  
echo -e "${LIGHT_BLUE}Choix du type de swap :${NC}"
echo "1. Swap zram (compression en mémoire)"
echo "2. Partition swap classique"
echo "3. Pas de swap"

while true; do  
    read -p "Sélectionnez une option (1, 2 ou 3) : " swap_choice  
    if [ "$swap_choice" = "1" ]; then  
        # Installer zram 
        echo -e "${LIGHT_BLUE}Configuration de zram pour le swap...${NC}"
        if ! modprobe zram; then  
            echo -e "${RED}Erreur lors du chargement de zram !${NC}"
            exit 1  
        fi

        # Configurer zram 
        echo -e "${LIGHT_BLUE}Création d'un swap zram de 2 Go...${NC}"
        echo 2G > /sys/block/zram0/disksize

        # Formater zram et activer 
        if mkswap /dev/zram0 && swapon /dev/zram0; then  
            echo -e "${LIGHT_BLUE}Swap zram activé avec succès !${NC}"
        else  
            echo -e "${RED}Erreur lors de la configuration du swap zram !${NC}"
            exit 1  
        fi  
        break  
    elif [ "$swap_choice" = "2" ]; then  
        # Configuration classique de partition swap  
        swap_partition="${disk}2"  # Supposons qu'il y a une deuxième partition pour le swap  
        echo -e "${LIGHT_BLUE}Création d'une partition de swap sur $swap_partition...${NC}"
        (
            echo ,+2G,  # Partition de swap d'une taille de 2 Go  
        ) | sfdisk "$disk" || { echo -e "${RED}Erreur lors de la création de la partition swap !${NC}"; exit 1; }

        # Formatage de la partition swap  
        mkswap "$swap_partition" || { echo -e "${RED}Erreur lors du formatage de la partition swap !${NC}"; exit 1; }
        swapon "$swap_partition" || { echo -e "${RED}Erreur lors de l'activation de la partition swap !${NC}"; exit 1; }
        echo -e "${LIGHT_BLUE}Partition swap activée avec succès !${NC}"
        break  
    elif [ "$swap_choice" = "3" ]; then  
        echo -e "${LIGHT_BLUE}Aucun swap ne sera configuré.${NC}"
        break  
    else  
        echo -e "${RED}Choix invalide. Veuillez sélectionner 1, 2 ou 3.${NC}"  
    fi  
done

# Choix du hostname  
read -p "Entrez le nom d'hôte pour votre système (par exemple, 'archlinux') : " hostname

# Installation de base 
echo -e "${LIGHT_BLUE}Installation du système de base...${NC}"
pacstrap /mnt base linux linux-firmware || { echo -e "${RED}Erreur lors de l'installation de la base !${NC}"; exit 1; }

# Configuration du système 
echo -e "${LIGHT_BLUE}Configuration du système...${NC}"
echo "/dev/mapper/cryptroot  /  ext4  defaults  0  1" >> /mnt/etc/fstab  

# Configuration des hooks LUKS uniquement si le chiffrement est utilisé  
if [ "$encrypt_choice" = "y" ]; then  
    echo "HOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)" > /mnt/etc/mkinitcpio.conf  
else  
    echo "HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)" > /mnt/etc/mkinitcpio.conf  
fi

# Régénérer l'initramfs  
echo -e "${LIGHT_BLUE}Régénération de l'initramfs...${NC}"
arch-chroot /mnt mkinitcpio -P || { echo -e "${RED}Erreur lors de la régénération de l'initramfs !${NC}"; exit 1; }

# Configuration du chroot  
arch-chroot /mnt /bin/sh <<EOF  
echo "Bienvenue sur votre nouvel Arch Linux !"
# Configuration locale  
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen  
locale-gen  
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf  
# Configuration du hostname  
echo "$hostname" > /etc/hostname  
EOF

# Gestion des utilisateurs 
read -p "Entrez le nom d'utilisateur pour votre système : " username

# Demander au utilisateur d'entrer un mot de passe pour le nouvel utilisateur  
read -sp "Entrez le mot de passe pour l'utilisateur $username : " user_password  
echo  
read -sp "Confirmez le mot de passe pour l'utilisateur $username : " user_password_confirm  
echo

# Vérifier si les mots de passe correspondent  
if [ "$user_password" != "$user_password_confirm" ]; then  
    echo -e "${RED}Les mots de passe ne correspondent pas. Veuillez réexécuter le script.${NC}"
    exit 1  
fi

# Création de l'utilisateur  
arch-chroot /mnt /bin/sh <<EOF  
useradd -m -G wheel "$username"  
echo "$username:$user_password" | chpasswd  
EOF

# Ajouter sudo si l'utilisateur a le groupe wheel  
echo -e "${LIGHT_BLUE}Configuration de sudo pour l'utilisateur...${NC}"
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

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
