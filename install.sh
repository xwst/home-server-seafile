#!/bin/bash

LINE_WIDTH=60
function ww() {
    cat | fold -s -w $LINE_WIDTH
}
function pw() {
    head -c $1 /dev/urandom | base64 -w 0 | sed 's#/##g' | head -c $1
}

echo -n "Please enter the base directory in which all borgmatic bind-mounts will be placed: ($(pwd))" | ww
read BASE_DIR
if [ -z $BASE_DIR ]; then
    BASE_DIR=$(pwd)
fi
mkdir -p $BASE_DIR

echo "The linuxserver.io-images require a user that will be the owner of the bind-mounted data within the docker containers. If you give a user name that does not exist, a new one will be created." | ww
echo -n "User name: "
read user;

if [ ! id "$user" &>/dev/null ]; then
    echo "User does not exist. Creating a new one."
    useradd -d $BASE_DIR \
            -c "docker user" \
            --no-create-home \
            --system \
            --user-group \
            $user
fi

uid=$(id -u $user)
gid=$(id -g $user)

echo "Please enter a single domain under which the server is accessible and for which a letsencrypt certificate shall be received. Additional domains may be configured manually later." | ww
echo -n "Domain: "
read domain;

echo "Creating environment file for docker-compose. Timezone is copied from host!" | ww
echo "BASE_DIR=$BASE_DIR" > .env
echo -en "PUID=$uid\nPGID=$gid\nMYDOMAIN=$domain\nTIMEZONE=" >> .env
cat /etc/timezone >> .env
chmod 600 .env
DB_ROOT_PW=$(pw 20)
DB_GITEA_PASSWORD=$(pw 20)
BORG_PASSPHRASE=$(pw 25)
echo "DB_ROOT_PW=$DB_ROOT_PW" >> .env
echo "DB_SEAFILE_PW=$(pw 20)" >> .env
echo "DB_GITEA_PASSWORD=$DB_GITEA_PASSWORD" >> .env
echo "BORG_PASSPHRASE=$BORG_PASSPHRASE" >> .env

echo "Creating ssh-key without password for borgmatic."
mkdir -p $BASE_DIR/borgmatic/.ssh \
         $BASE_DIR/borgmatic/.cache/borg \
         $BASE_DIR/borgmatic/.config/borg \
         $BASE_DIR/borgmatic/borgmatic.d 
ssh-keygen -N "" -t ed25519 -f $BASE_DIR/borgmatic/.ssh/id_ed25519


echo "Starting server to configure database server." | ww
docker-compose up -d

echo -n "Waiting for mariadb to be ready."
while true; do
	sleep 2
	echo -n "."
	(docker exec -it mariadb mysql -u root -e "SELECT version();" -p"$DB_ROOT_PW") 2>/dev/null > /dev/null && break
done
echo ""

# Setup databases
SQL_SCRIPT=$(sed "s/%DB_GITEA_PASSWORD%/$GITEA_DB_PASSWORD/" setup_db.sql)
docker exec -it mariadb /bin/bash -c "echo \"$SQL_SCRIPT\" | mysql -u root -p\"$DB_ROOT_PW\""

echo "Creating default borgmatic configuration."
docker exec borgmatic \
	bash -c "cd && generate-borgmatic-config -d /etc/borgmatic.d/config.yaml.template"
cp borgmatic_config.yaml $BASE_DIR/borgmatic/borgmatic.d/config.yaml
exit

echo "Configuration complete, stopping server." | ww
docker-compose down
echo "Various passwords have been generated automatically. You can find them in the './.env'-file. You may now start the services using docker-compose. Do not forget to configure the ddclient by editing $BASE_DIR/ddclient/ddclient.conf." | ww
