# home-server-seafile
Docker related files for service deployment

## Features
- linuxserver.io-SWAG as https-server
- Seafile with OnlyOffice support, gitea and radicale accessible via subfolders (only one domain required)
- mariadb and ddclient as background services
- borgmatic container to back up data using borgbackup
- data sharing between containers using named volumes instead of bind mounts
- only borgmatic volumes are bind-mounted to configure borgmatic and back up the repository key file

## Anti-Features
- gitea container runs its service using `UID=1000`, which is different from the `UID` used by the linuxserver.io-containers. As long as you stick to named volumes this is not an issue, but be careful if you bind mount the gitea-data volume, as you will give a host user access to all repositories.

## Setup
There is an install script to perform most of the setup steps automatically.
If you do not trust the script, just read it and perform the instructions on your own.
Parts of the service configuration need to be done manually.
See the subsections below.
You can either create a temporary container or use the borgmatic container to access the files in named volumes or use `docker cp` to copy the files to your local directory and back to the named volume.

#### ddclient
[ddclient](https://ddclient.net/) configuration depends on the used service. Please consult the official manual.

#### Seafile
- Within the seafile docker container edit
	- `/shared/seafile/conf/seafile.conf` and set `host = 0.0.0.0` in the `[fileserver]` section.
	- `/shared/seafile/conf/gunicorn.conf.py` and set `bind = "0.0.0.0:8000`.
	- `/shared/seafile/conf/seahub_settings.py` and adjust `SERVICE_URL` and `FILE_SERVER_ROOT` to match your subdomain.

#### borgmatic
- Configuration
	- Add repository URL
	- Add encryption passcommand or passphrase
	- Adjust crontab if required
- Add SSH public key to authorized\_keys on remote backup server
- Create known\_hosts-file (or run a SSH command interactively to autogenerate one)
- Initialize repository if not already done
- Make a backup of everything you need to restore a borgmatic archive as described in section 'Backup and Restore'.

#### gitea
- Modify the file `/etc/gitea/app.ini` within the container:
	- Change `ROOT_URL` to `https://$domain/gitea/`, where `$domain` is the domain under which the server is accessible.
	- You may disable SSH, as the current setup does not provide access to gitea's SSH server.
- Visit `https://$domain/gitea/` and finish the installation.

## Backup and Restore
todo
