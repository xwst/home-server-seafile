#!/bin/bash

LINE_WIDTH=60
function ww() {
    cat | fold -s -w $LINE_WIDTH
}
function pw() {
    head -c $1 /dev/urandom | base64 -w 0 | sed 's#/##g' | head -c $1
}


echo "The linuxserver.io-images require a user that will be the owner of the persistent data within the docker containers. If you give a user name that does not exist, a new one will be created." | ww
echo -n "User name: "
read user;

if [ ! id "$user" &>/dev/null ]; then
    echo "User does not exist. Creating a new one."
    useradd -d /opt/$user \
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
echo -en "PUID=$uid\nPGID=$gid\nMYDOMAIN=$domain\nTIMEZONE=" >> .env
cat /etc/timezone >> .env
chmod 600 .env
DB_ROOT_PW=$(pw 20)
DB_GITEA_PASSWORD=$(pw 20)
echo "DB_ROOT_PW=$DB_ROOT_PW" >> .env
echo "DB_GITEA_PASSWORD=$DB_GITEA_PASSWORD" >> .env



echo -n "Starting database and web server to perform initial setup." | ww
# Borgmatic is started to adjust permissions of the gitea volumes
docker-compose up -d swag mariadb borgmatic
while true; do
	sleep 2
	echo -n "."
	(docker exec -it mariadb mysql -u root -e "SELECT version();" -p"$DB_ROOT_PW") 2>/dev/null > /dev/null && break
done
sleep 2
echo ""

docker exec borgmatic mkdir -p /source/radicale/data/collections
docker exec borgmatic chown -R $uid:$gid /source/radicale
docker cp borgmatic_crontab.txt borgmatic:/etc/borgmatic.d/crontab.txt
echo "Creating ssh-key without password for borgmatic."
docker exec borgmatic ssh-keygen -N "" -t ed25519 -f /root/.ssh/id_ed25519

echo "Starting remaining services." | ww
docker-compose up -d
docker cp seafile.subfolder.conf swag:/config/nginx/proxy-confs/
docker cp swag:/config/nginx/proxy-confs/gitea.subfolder.conf.sample \
	  ./gitea.subfolder.conf.sample
docker cp ./gitea.subfolder.conf.sample \
	  swag:/config/nginx/proxy-confs/gitea.subfolder.conf
docker cp ./radicale.subfolder.conf swag:/config/nginx/proxy-confs/
curl -s -o radicale.conf https://raw.githubusercontent.com/tomsquest/docker-radicale/master/config
docker cp radicale.conf radicale:/config/config
rm -f ./gitea.subfolder.conf.sample ./radicale.conf


echo "Creating default borgmatic configuration."
docker exec borgmatic \
	bash -c "cd && generate-borgmatic-config -d /etc/borgmatic.d/config.yaml.template"
docker cp borgmatic_config.yaml borgmatic:/etc/borgmatic.d/config.yaml

echo "Configuration complete, stopping server." | ww
docker-compose down

echo "Various passwords have been generated automatically. You can find them in the './.env'-file. You may now start the services using docker-compose. Do not forget to perform the manual configuration steps." | ww
