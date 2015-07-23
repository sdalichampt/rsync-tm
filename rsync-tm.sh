#!/bin/bash

if [ -e /var/lock/$0.lock ]
then
  # Execution déjà en cours
  notify-send \
    --urgency=low \
    --expire-time=10000 \
    "Rsync TimeMachine" \
    "Une autre sauvegarde est en cours.";

  exit 0;
fi

# Mise en place d'un vérou interdisant les autres execution
touch /var/lock/$0.lock;

# Suppression du verrou en fin d'execution
trap 'rm /var/lock/$0.lock' 0 1 2 3 15;

## Collecte des parametres
source_dir=$1;
destination_host=$2;
destination_dir=$3;
exclude_file=$4;

date=$(date +%Y%m%d%H%M%S);


# Vérification du repertoire a sauvegarder
if [ ! -d "$source_dir" ]
then
  notify-send \
    --urgency=critical \
    "Rsync TimeMachine" \
    "Le repertoire <b>$source_dir</b> n'existe pas. La sauvegarde n'est pas éffectuée.";

  exit 1;
fi

# Vérification de la connexion au serveur distant
ssh -q -6 $destination_host exit;

if [ $? -ne 0 ]
then
  notify-send \
    --urgency=normal \
    --expire-time=3600000 \
    "Rsync TimeMachine" \
    "Le serveur <b>$destination_host</b> est inaccessible avec l'utilisateur. La sauvegarde n'est pas éffectuée.";

  exit 1;
fi

# Vérification de la connexion au repertoire de destination
ssh -q -6 $destination_host [[ -d $destination_dir ]];

if [ $? -ne 0 ]
then
  notify-send \
    --urgency=critical \
    "Rsync TimeMachine" \
    "Le repertoire <b>$destination_dir</b> n'existe pas sur le serveur <b>$destination_host</b>. La sauvegarde n'est pas éffectuée.";

  exit 1;
fi

# Execution de la sauvegarde

rsync -aPv \
  -6 \
  --human-readable \
  --compress \
  --delete-during \
  --stats \
  --exclude-from=$exclude_file \
  --link-dest=$destination_dir/current $source_dir $destination_host:$destination_dir/incomplete | tee /tmp/backup$date.log;

if [ $? -ne 0 ]
then
  notify-send \
    --urgency=critical \
    "Rsync TimeMachine" \
    "Echec de la sauvegarde";

  exit 1;
fi

# Sauvegarde du jounal de synchronisation sur le serveur distant
scp -q -6 /tmp/backup$date.log $destination_host:$destination_dir/incomplete/backup$date.log;
rm -f /tmp/backup$date.log;

# Creation du lien qui version le denier état sauvegardé
ssh -q -6 $destination_host "mv $destination_dir/incomplete $destination_dir/$date \
      && rm -f $destination_dir/current \
      && ln -s $date $destination_dir/current";

# Suppresion des sauvegarde de plus de 60 jours
ssh -q -6 $destination_host "find $destination_dir/ -maxdepth 1 -type d -mtime +60 | xargs rm -rf";

# Fin de la sauvegarde
notify-send \
  --urgency=low \
  --expire-time=10000 \
  "Rsync TimeMachine" \
  "La sauvegarde est terminée.";

exit 0;
