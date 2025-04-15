#!/bin/bash

echo "Installation d'Arch Linux"

# Mettre à jour l'horloge  
echo "Mise à jour de l'horloge"
timedatectl set-ntp true
echo "ETAPE 1 - PARTITIONNEMENT DU DISQUE"
# Avertissement sur le partitionnement  
echo "---------------------------------------------------"
echo "AVERTISSEMENT : Cette opération va effacer toutes les données sur le disque spécifié."
echo "Veuillez vous assurer que vous avez sauvegardé toutes vos données importantes avant de continuer."
echo "Voici les disques disponibles :"
lsblk

# Demander à l'utilisateur d'entrer le disque à partitionner  
echo "Entrez le disque à partitionner (ex : /dev/sda) : "
read -r disk

echo "Voulez-vous vraiment continuer à partitionner $disk ? (y/n)"
read -r confirm

if [[ "$confirm" != "y" ]]; then  
    echo "Opération annulée. Aucune modification n'a été apportée."
    exit 1  
fi

# Demander si l'utilisateur veut formater les partitions  
echo "Voulez-vous formater les partitions existantes sur $disk ? (y/n)"
read -r format_choice

# Demander la taille des partitions  
echo "Entrez la taille de la partition root (ex: 100G), ou écrivez 'tout' pour utiliser tout le disque :"
read -r root_size  
echo "Entrez la taille de la partition swap (ex: 2G) :"
read -r swap_size  
echo "Entrez la taille de la partition home (ex: 100G) :"
read -r home_size

# Partitionner le disque  
echo "Partitionnement du disque $disk..."
parted $disk mklabel gpt  

if [[ "$format_choice" == "y" ]]; then  
    if [[ "$root_size" == "tout" ]]; then  
        # Utiliser tout le disque pour la partition root  
        parted $disk mkpart primary ext4 1MiB 100%
    else  
        # Créer la partition root avec la taille spécifiée  
        parted $disk mkpart primary ext4 1MiB "$root_size"
        # Créer la partition swap  
        parted $disk mkpart primary linux-swap "$root_size" "$(( $(echo $root_size | sed 's/G//') + $(echo $swap_size | sed 's/G//') ))GiB"
        # Créer la partition home  
        parted $disk mkpart primary ext4 "$(( $(echo $root_size | sed 's/G//') + $(echo $swap_size | sed 's/G//') ))GiB" 100%
    fi  
else  
    echo "En utilisant les partitions existantes. Assurez-vous qu'elles sont configurées correctement."
fi

# Formater les partitions  
mkfs.ext4 ${disk}1 
mkswap ${disk}2  
mkfs.ext4 ${disk}3

# Monter les partitions  
mount ${disk}1 /mnt  
mkdir /mnt/home  
mount ${disk}3 /mnt/home  
swapon ${disk}2

# Choix des miroirs  
echo "---------------------------------------------------"
echo "Configuration des miroirs..."
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup  
echo "Voulez-vous utiliser les miroirs par défaut ou en ajouter d'autres ? (d/a)"
read -r mirror_choice

if [[ "$mirror_choice" == "a" ]]; then  
    nano /etc/pacman.d/mirrorlist  # L'utilisateur peut éditer le fichier des miroirs  
else  
    echo "Utilisation des miroirs par défaut."
fi

# Choix du noyau  
echo "---------------------------------------------------"
echo "Choisissez le noyau à installer :"
echo "1) Noyau standard (linux)"
echo "2) Noyau LTS (linux-lts)"
echo "3) Noyau Hardened (linux-hardened)"
echo "4) Noyau Zen (linux-zen)"
echo "Entrez le numéro de votre choix :"
read -r kernel_choice

# Installer le système de base avec le noyau choisi  
if [[ "$kernel_choice" == "1" ]]; then  
    pacstrap /mnt base linux linux-headers linux-firmware base-devel  
elif [[ "$kernel_choice" == "2" ]]; then  
    pacstrap /mnt base linux-lts linux-lts-headers linux-firmware base-devel  
elif [[ "$kernel_choice" == "3" ]]; then  
    pacstrap /mnt base linux-hardened linux-hardened-headers linux-firmware base-devel  
elif [[ "$kernel_choice" == "4" ]]; then  
    pacstrap /mnt base linux-zen linux-zen-headers linux-firmware base-devel  
else  
    echo "Choix invalide, installation du noyau standard."
    pacstrap /mnt base linux linux-headers linux-firmware base-devel  
fi

# Générer le fichier fstab  
genfstab -U /mnt >> /mnt/etc/fstab

# Choix des locales  
echo "---------------------------------------------------"
echo "Configuration des locales..."
echo "Choisissez votre langue :"
echo "1) Français"
echo "2) Anglais"
echo "Entrez le numéro de votre choix :"
read -r language_choice

# Configuration des locales selon le choix  
if [[ "$language_choice" == "1" ]]; then  
    arch-chroot /mnt /bin/bash -c "echo 'fr_FR.UTF-8 UTF-8' >> /etc/locale.gen"
    echo "LANG=fr_FR.UTF-8" > /mnt/etc/locale.conf  
    LC_TZ="Europe/Paris"
elif [[ "$language_choice" == "2" ]]; then  
    arch-chroot /mnt /bin/bash -c "echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen"
    echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf  
    LC_TZ="America/New_York" 
else  
    echo "Choix invalide. Utilisation du français par défaut."
    arch-chroot /mnt /bin/bash -c "echo 'fr_FR.UTF-8 UTF-8' >> /etc/locale.gen"
    echo "LANG=fr_FR.UTF-8" > /mnt/etc/locale.conf  
    LC_TZ="Europe/Paris"
fi  

arch-chroot /mnt /bin/bash -c "locale-gen"
echo "LC_TZ=$LC_TZ" >> /mnt/etc/locale.conf

# Choix du fuseau horaire  
echo "---------------------------------------------------"
echo "Configuration du fuseau horaire :"
echo "Entrez votre fuseau horaire (ex: 'Europe/Paris') :"
read -r timezone  
echo "$timezone" > /mnt/etc/timezone  
ln -sf /usr/share/zoneinfo/$timezone /mnt/etc/localtime

# Option Zram pour le swap  
echo "---------------------------------------------------"
echo "Souhaitez-vous activer Zram pour le swap ? (y/n)"
read -r zram_choice

if [[ "$zram_choice" == "y" ]]; then  
    echo "Activation de Zram..."
    arch-chroot /mnt /bin/bash -c "pacman -S --noconfirm zram-generator"
    echo "KERNEL==\"zram0\", NAME=\"zram0\", COMMAND=\"/usr/bin/sh -c 'zramctl --find --size ${swap_size}G'\" >> /mnt/etc/udev/rules.d/99-zram.rules  
    echo 'zram0 /dev/zram0 swap sw 0 0' >> /mnt/etc/fstab  
fi

# Choix du serveur d'affichage  
echo "---------------------------------------------------"
echo "Choisissez le serveur d'affichage que vous souhaitez utiliser :"
echo "1) Wayland (par défaut)"
echo "2) Xorg"
echo "3) Pas de serveur d'affichage"
echo "Entrez le numéro de votre choix :"
read -r display_choice

if [[ "$display_choice" == "1" ]]; then  
    echo "Installation de Wayland..."
    arch-chroot /mnt pacman -S --noconfirm wayland  
elif [[ "$display_choice" == "2" ]]; then  
    echo "Installation de Xorg..."
    arch-chroot /mnt pacman -S --noconfirm xorg-server xorg-apps xorg-xinit  
elif [[ "$display_choice" == "3" ]]; then  
    echo "Aucun serveur d'affichage sélectionné."
else  
    echo "Choix invalide, aucune installation de serveur d'affichage effectuée."
fi

# Choix des pilotes graphiques  
echo "---------------------------------------------------"
echo "Choisissez les pilotes graphiques que vous souhaitez installer :"
echo "1) NVIDIA"
echo "2) AMD"
echo "3) Intel"
echo "4) VMware"
echo "5) VirtualBox"
echo "6) Pas de pilote graphique"
echo "Entrez le numéro de votre choix :"
read -r gpu_choice

case $gpu_choice in  
    1)
        echo "Installation des pilotes NVIDIA..."
        arch-chroot /mnt pacman -S --noconfirm nvidia nvidia-utils  
        ;;
    2)
        echo "Installation des pilotes AMD..."
        arch-chroot /mnt pacman -S --noconfirm xf86-video-amdgpu  
        ;;
    3)
        echo "Installation des pilotes Intel..."
        arch-chroot /mnt pacman -S --noconfirm xf86-video-intel  
        ;;
    4)
        echo "Installation des pilotes VMware..."
        arch-chroot /mnt pacman -S --noconfirm open-vm-tools  
        ;;
    5)
        echo "Installation des pilotes VirtualBox..."
        arch-chroot /mnt pacman -S --noconfirm virtualbox-guest-utils  
        ;;
    6)
        echo "Aucun pilote graphique sélectionné."
        ;;
    *)
        echo "Choix invalide, aucune installation de pilote graphique effectuée."
        ;;
esac

# Choix du gestionnaire de connexion  
echo "---------------------------------------------------"
echo "Choisissez le gestionnaire de connexion que vous souhaitez utiliser :"
echo "1) SDDM (Simple Desktop Display Manager pour KDE)"
echo "2) GDM (GNOME Display Manager)"
echo "3) LightDM"
echo "4) Pas de gestionnaire de connexion"
echo "Entrez le numéro de votre choix :"
read -r dm_choice

if [[ "$dm_choice" == "1" ]]; then  
    echo "Installation de SDDM..."
    arch-chroot /mnt pacman -S --noconfirm sddm  
elif [[ "$dm_choice" == "2" ]]; then  
    echo "Installation de GDM..."
    arch-chroot /mnt pacman -S --noconfirm gdm  
elif [[ "$dm_choice" == "3" ]]; then  
    echo "Installation de LightDM..."
    arch-chroot /mnt pacman -S --noconfirm lightdm lightdm-gtk-greeter  
elif [[ "$dm_choice" == "4" ]]; then  
    echo "Aucun gestionnaire de connexion sélectionné."
else  
    echo "Choix invalide, aucune installation de gestionnaire de connexion effectuée."
fi

# Configuration réseau (exemple avec dhcpcd)
echo "---------------------------------------------------"
echo "Voulez-vous configurer le réseau avec dhcpcd ? (y/n)"
read -r net_choice

if [[ "$net_choice" == "y" ]]; then  
    arch-chroot /mnt /bin/bash -c "pacman -S --noconfirm dhcpcd"
    echo "Démarrer dhcpcd au démarrage ? (y/n)"
    read -r start_dhcpcd  
    if [[ "$start_dhcpcd" == "y" ]]; then  
        echo "systemctl enable dhcpcd" >> /mnt/etc/rc.conf  
    fi  
fi

# Changer de racine et configurer le système  
arch-chroot /mnt /bin/bash <<EOF  
# Configurer le système  
echo "$hostname" > /etc/hostname  
pacman -Syu --noconfirm  
echo "Définissez le mot de passe root :"
read -r root_password  
if [ -z "$root_password" ]; then  
    echo "Mot de passe vide. Désactivation du compte root."
    usermod -L root  # Désactive le compte root  
else  
    echo "$root_password" | passwd --stdin root # Définit le mot de passe root  
fi

# Création d'un nouvel utilisateur  
echo "Entrez un nom d'utilisateur :"
read -r username  
useradd -m -G wheel "$username"
echo "Définissez le mot de passe pour l'utilisateur $username :"
passwd "$username"

# Installation de GRUB  
pacman -S --noconfirm grub  
grub-install --target=i386-pc $disk  
grub-mkconfig -o /boot/grub/grub.cfg  
EOF

# Demander à l'utilisateur s'il veut installer un environnement de bureau  
echo "Souhaitez-vous installer un environnement de bureau ? (y/n)"
read -r choice

if [[ "$choice" == "y" ]]; then  
    echo "Quel environnement de bureau voulez-vous installer ?"
    echo "1) KDE"
    echo "2) GNOME"
    echo "3) XFCE"
    echo "4) MATE"
    echo "Entrez le numéro de votre choix :"
    read -r desktop_choice

    case $desktop_choice in  
        1)
            echo "Installation de KDE..."
            arch-chroot /mnt pacman -S --noconfirm plasma kde-applications  
            ;;
        2)
            echo "Installation de GNOME..."
            arch-chroot /mnt pacman -S --noconfirm gnome gnome-extra  
            ;;
        3)
            echo "Installation de XFCE..."
            arch-chroot /mnt pacman -S --noconfirm xfce4 xfce4-goodies  
            ;;
        4)
            echo "Installation de MATE..."
            arch-chroot /mnt pacman -S --noconfirm mate mate-extra  
            ;;
        *)
            echo "Choix invalide, aucune installation d'environnement de bureau effectuée."
            ;;
    esac  
fi

# Terminer  
echo "Installation terminée ! Redémarrez l'ordinateur."
# Terminer
echo "Installation terminée ! Redémarrez l'ordinateur."
