#!/bin/bash

# Menu titre
echo "Installation d'Arch Linux"
echo "-------------------------"

# Met l'horloge à jour
echo "Mise à jour de l'horloge"
timedatectl set-ntp true

# Partitionne le disque
echo "-------------------------"
echo "Partionnement du disque"
echo "                         "

# Message d'avertissement
echo "AVERTISSEMENT : Cette opération va effacer toutes les données sur le disque spécifié."
echo "Veuillez vous assurer que vous avez sauvegardé toutes vos données importantes avant de continuer."
echo "                                                          "  

# Choix du disque à partitionner
echo "Sélectionnez un disque à partitionner parmi les suivants :"
lsblk -d -n -o NAME,SIZE | nl

# Demande à l'utilisateur de rentrer le numéro du disque à partitionner 
read -p "Entrez le numéro du disque : " num

# Récupère le nom du disque correspondant au numéro  
disque=$(lsblk -d -n -o NAME | sed -n "${num}p")

# Vérifie si le disque existe  
if [[ -z "$disque" ]]; then  
  echo "Disque non valide. Fin du script."
  exit 1  
fi

echo "Vous avez choisi le disque : /dev/$disque"



