# home-server-seafile
Docker related files for service deployment

## Features
- linuxserver.io-SWAG as https-server
- Seafile with OnlyOffice support, gitea and radicale accessible via subfolders (only one domain required)
- mariadb and ddclient as background services
- borgmatic container to back up data using borgbackup
- data sharing between containers using named volumes instead of bind mounts
- only borgmatic volumes are bind-mounted to configure borgmatic and back up the repository key file

## Setup
The following steps need to be done in order to configure the services:
### These steps can be automated using the `install.sh`-script
1. Create a dedicated linux user whos UID will be used to run the services within the containers.
2. Specify passwords and timezone in `.env`-file.
3. Create database and database users for gitea

### These steps need to be done manually
4. Insert your domain name in nginx's reverse proxy configuration. 
5. Configure ddclient, seafile, gitea, radicale and borgmatic

##### borgmatic
- Configure
	- Add repository URL
	- Add encryption passcommand or passphrase
	- Adjust crontab if required
- Add SSH public key to authorized\_keys
- Create known\_hosts-file (or run a SSH command interactively to autogenerate one)
- Initialize repository if not already done

## Backup and Restore
todo
