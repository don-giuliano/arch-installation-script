#!/bin/sh


# Définir quelques couleurs pour le texte  
LIGHT_BLUE='\033[1;34m'  
RED='\033[0;31m'
NC='\033[0m'  # Pas de couleur

# Fonction pour afficher un message d'erreur  
error_msg() {
    whiptail --title "$error_title" --msgbox "$1" 8 45  
    exit 1  
}

# Choix de la langue  
lang=$(whiptail --title "Choix de la langue" --menu "Sélectionnez votre langue :" 15 60 6 \
    "1" "Français" \
    "2" "English" \
    "3" "Español" \
    "4" "Deutsch" \
    "5" "Italiano" \
    "6" "Português" 3>&1 1>&2 2>&3) || exit

# Messages en fonction de la langue  
case $lang in  
    1) 
        error_title="Erreur"
        welcome_msg="Bienvenue dans le script d'installation d'Arch Linux !"
        connection_error="Aucune connexion internet détectée ! Veuillez vérifier votre connexion."
        whiptail_error="Erreur : whiptail n'est pas installé."
        hostname_msg="Entrez le nom d'hôte :"
        swap_zram_msg="Swap zram"
        swap_partition_msg="Partition swap classique"
        no_swap_msg="Pas de swap"
        ;;
    2) 
        error_title="Error"
        welcome_msg="Welcome to the Arch Linux installation script!"
        connection_error="No internet connection detected! Please check your connection."
        whiptail_error="Error: whiptail is not installed."
        hostname_msg="Enter hostname:"
        swap_zram_msg="Swap zram"
        swap_partition_msg="Classic swap partition"
        no_swap_msg="No swap"
        ;;
    3) 
        error_title="Error"
        welcome_msg="¡Bienvenido al script de instalación de Arch Linux!"
        connection_error="¡No se detecta conexión a Internet! Verifique su conexión."
        whiptail_error="Error: whiptail no está instalado."
        hostname_msg="Ingrese el nombre del host:"
        swap_zram_msg="Swap zram"
        swap_partition_msg="Partición swap clásica"
        no_swap_msg="Sin swap"
        ;;
    4) 
        error_title="Fehler"
        welcome_msg="Willkommen im Arch Linux Installationsskript!"
        connection_error="Keine Internetverbindung erkannt! Bitte überprüfen Sie Ihre Verbindung."
        whiptail_error="Fehler: whiptail ist nicht installiert."
        hostname_msg="Hostname eingeben:"
        swap_zram_msg="Swap zram"
        swap_partition_msg="Klassische Swap-Partition"
        no_swap_msg="Kein Swap"
        ;;
    5) 
        error_title="Errore"
        welcome_msg="Benvenuto nello script di installazione di Arch Linux!"
        connection_error="Nessuna connessione a Internet rilevata! Controlla la tua connessione."
        whiptail_error="Errore: whiptail non è installato."
        hostname_msg="Inserisci il nome host:"
        swap_zram_msg="Swap zram"
        swap_partition_msg="Partizione swap classica"
        no_swap_msg="Nessuno swap"
        ;;
    6) 
        error_title="Erro"
        welcome_msg="Bem-vindo ao script de instalação do Arch Linux!"
        connection_error="Nenhuma conexão com a Internet detectada! Verifique sua conexão."
        whiptail_error="Erro: whiptail não está instalado."
        hostname_msg="Insira o nome do host:"
        swap_zram_msg="Swap zram"
        swap_partition_msg="Partição swap clássica"
        no_swap_msg="Sem swap"
        ;;
    *) 
        error_msg "Langue non valide." 
        ;;
esac

# Affichage du message de bienvenue  
whiptail --title "Bienvenue !" --msgbox "$welcome_msg" 10 60

# Vérification de la connexion Internet  
ping -c 1 archlinux.org > /dev/null 2>&1  
[ $? -ne 0 ] && error_msg "$connection_error"

# Vérifier que whiptail est installé  
command -v whiptail >/dev/null || error_msg "$whiptail_error"

# Choix du layout de clavier  
keyboard_layout=$(whiptail --title "Choix du layout de clavier" --menu "Sélectionnez votre layout :" 15 60 6 \
    "us" "English (United States)" \
    "fr" "Français" \
    "de" "Deutsch" \
    "es" "Español" \
    "it" "Italiano" \
    "uk" "English (United Kingdom)" 3>&1 1>&2 2>&3) || exit  
loadkeys "$keyboard_layout"

# Affichage des disques disponibles avec un numéro  
disks=$(lsblk -d -n -o NAME | awk '{print "/dev/"$1}')
disk_choices=()
i=1  
for disk in $disks; do  
    size=$(lsblk -d -n -o SIZE "$disk")
    disk_choices+=("$i" "$disk ($size)") 
    i=$((i + 1))
done

# Sélection du disque à partitionner  
disk_number=$(whiptail --title "Choix du disque" --menu "Sélectionnez le disque à partitionner :" 15 60 $((i-1)) "${disk_choices[@]}" 3>&1 1>&2 2>&3) || exit  
disk=$(echo "$disks" | sed -n "${disk_number}p")

# Choisir le chiffrement LUKS  
(whiptail --title "Chiffrement LUKS" --yesno "Chiffrer le disque avec LUKS ?" 8 45) && encrypt_choice="y" || encrypt_choice="n"

# Option de partitionnement  
partition_choice=$(whiptail --title "Méthode de partitionnement" --menu "Sélectionnez une option :" 15 60 2 \
    "1" "Partitionnement automatique" \
    "2" "Partitionnement avancé avec cfdisk" 3>&1 1>&2 2>&3) || exit

# Partitionnement  
if [ "$partition_choice" = "1" ]; then  
    (echo ,,,) | sfdisk "$disk" || error_msg "Erreur lors de la création des partitions !"
elif [ "$partition_choice" = "2" ]; then  
    cfdisk "$disk" || error_msg "Erreur lors de l'utilisation de cfdisk !"
fi

# Chiffrement LUKS si sélectionné  
partition="${disk}1"
if [ "$encrypt_choice" = "y" ]; then  
    cryptsetup luksFormat "$partition" || error_msg "Erreur lors du chiffrement de la partition !"
    cryptsetup open "$partition" cryptroot || error_msg "Erreur lors de l'ouverture du volume chiffré !"
    partition="/dev/mapper/cryptroot"
fi

# Formatage et montage  
mkfs.ext4 "$partition" || error_msg "Erreur lors du formatage de la partition !"
mount "$partition" /mnt || error_msg "Erreur lors du montage de la partition !"

# Choix du type de swap  
swap_choice=$(whiptail --title "Choix du type de swap" --menu "Sélectionnez une option :" 15 60 3 \
    "1" "$swap_zram_msg" \
    "2" "$swap_partition_msg" \
    "3" "$no_swap_msg" 3>&1 1>&2 2>&3) || exit

# Configuration du swap  
case $swap_choice in  
    1)
        modprobe zram || error_msg "Erreur lors du chargement de zram !"
        echo 2G > /sys/block/zram0/disksize  
        mkswap /dev/zram0 && swapon /dev/zram0 || error_msg "Erreur lors de la configuration de zram !"
        ;;
    2)
        swap_partition="${disk}2"
        (echo ,+2G) | sfdisk "$disk" || error_msg "Erreur lors de la création de la partition swap !"
        mkswap "$swap_partition" || error_msg "Erreur lors du formatage de la partition swap !"
        swapon "$swap_partition" || error_msg "Erreur lors de l'activation de la partition swap !"
        ;;
    3) echo -e "${LIGHT_BLUE}Aucun swap ne sera configuré.${NC}";;
    *) error_msg "Choix invalide." ;;
esac

# Choix du hostname  
hostname=$(whiptail --inputbox "$hostname_msg" 8 60 "archlinux" 3>&1 1>&2 2>&3) || exit

# Installation du système de base  
pacstrap /mnt base linux linux-firmware || error_msg "Erreur lors de l'installation de la base !"

# Configuration  
arch-chroot /mnt /bin/sh <<EOF  
echo "$hostname" > /etc/hostname  
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen  
locale-gen  
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf  
EOF

# Gestion des utilisateurs 
read -p "Entrez le nom d'utilisateur : " username  
read -sp "Entrez le mot de passe : " user_password  
echo  
read -sp "Confirmez le mot de passe : " user_password_confirm  
echo

if [ "$user_password" != "$user_password_confirm" ]; then  
    error_msg "Les mots de passe ne correspondent pas !"
fi

# Création de l'utilisateur et configuration sudo 
arch-chroot /mnt /bin/sh <<EOF  
useradd -m -G wheel "$username"  
echo "$username:$user_password" | chpasswd  
EOF

echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers.d/${username}

# Installation du bootloader 
read -p "Vous utilisez GRUB ? (y/n) : " grub_choice 
if [ "$grub_choice" = "y" ]; then  
    arch-chroot /mnt /bin/sh <<EOF  
pacman -S grub  
grub-install --target=i386-pc /dev/sda || error_msg "Erreur lors de l'installation de GRUB !"  
grub-mkconfig -o /boot/grub/grub.cfg || error_msg "Erreur lors de la génération de la configuration de GRUB !"  
EOF  
else  
    echo -e "${LIGHT_BLUE}GRUB ne sera pas installé.${NC}"
fi

# Finalisation 
echo -e "${LIGHT_BLUE}Installation terminée ! Redémarrez votre système.${NC}"
