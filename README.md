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
- gitea container runs its service using `UID=1000`, which is different from the `UID` used by the linuxserver.io-containers. As long as you stick to named volumes this is not an issue, but be careful if you bind mount the gitea-data volume, as you might give a host user access to all repositories.

## Setup
There is an install script to perform most of the setup steps automatically.
If you do not trust the script, just read it and perform the instructions on your own.
Parts of the service configuration need to be done manually.
See the subsections below.
You can either create a temporary container or use the borgmatic container to access the files in named volumes or use `docker cp` to copy the files to your local directory and back to the named volume.

### ddclient
[ddclient](https://ddclient.net/) configuration depends on the used service. Please consult the official manual.

### Seafile
- Within the seafile docker container edit
	- `/shared/seafile/conf/seafile.conf` and set `host = 0.0.0.0` in the `[fileserver]` section.
	- `/shared/seafile/conf/gunicorn.conf.py` and set `bind = "0.0.0.0:8000`.
	- `/shared/seafile/conf/seahub_settings.py`, set the variables `SERVICE_URL = 'https://$domain/seafile'` and `FILE_SERVER_ROOT = 'https://$domain/seafhttp'`, where you have to replace `$domain` with your domain, as well as
```
        SERVE_STATIC = True
        MEDIA_URL = '/seafmedia/'
        COMPRESS_URL = MEDIA_URL
        STATIC_URL = MEDIA_URL + 'assets/'
        SITE_ROOT = '/seafile/'
        LOGIN_URL = SITE_ROOT + 'accounts/login/'
```

### borgmatic
- Configuration (`/etc/borgmatic.d/config.yaml` within the container)
	- Add repository URL
	- Add encryption passcommand or passphrase
	- Adjust crontab if required
- Provide mail credentials in `/etc/borgmatic.d/msmtp.env` (see template file for details)
- Add SSH public key to authorized\_keys on remote backup server
- Create known\_hosts-file (or run a SSH command interactively to autogenerate one)
- Initialize repository if not already done
- Make a backup of everything you need to restore a borgmatic archive as described in section 'Backup and Restore'.

### gitea
- Modify the file `/etc/gitea/app.ini` within the container:
	- Change `ROOT_URL` to `https://$domain/gitea/`, where `$domain` is the domain under which the server is accessible.
	- You may disable SSH, as the current setup does not provide access to gitea's SSH server.
- Visit `https://$domain/gitea/` and finish the installation.

## Backup and Restore
In order to restore archives from the borg repositories you need at least a copy of the borg repository key, but its a good idea to also have a separate copy of the SSH keys and borgmatic configuration. That way, archives can be restored with a few simple commands.

To rebuild the entire setup, one also needs the `docker-compose.yaml`-file, as well as the environment variables `MYDOMAIN`, `PUID`, `PGID` and `TIMEZONE` stored in `.env`. (If you remove the passwords from the `.env`-file, you also need to remove the corresponding lines from `docker-compose.yaml`.)

### Backup of borg/borgmatic files 
Having borg/borgmatic files backed up to your borg repository will not help much. A tarball of all important files can be created on the host using
```docker exec borgmatic bash -c "tar -c /etc/borgmatic.d /root/.ssh /root/.config/borg" > borg.tar```
It might be a good idea to have the SSH and borg keys printed on a plain sheet of paper. (Check the [borg manual](https://borgbackup.readthedocs.io/en/stable/usage/key.html#borg-key-export) for details.)

If you plan to migrate to a different server, you may also want to include the borg cache into the tarball by adding `/root/.cache/borg`.

### Restoration
If you want to restore an older archive on the same host with everything set up, you can skip the first two steps, but need to call `docker-compose down` to stop all running containers.
1. Place `docker-compose.yaml`, the stripped `.env`-file and the borg tarball in a directory of your choice.
2. Bring up the `borgmatic` container only and extract the tarball within:
```
docker-compose up -d borgmatic
docker cp borg.tar borgmatic:/tmp
docker exec borgmatic tar -xf /tmp/borg.tar
```
3. Restore an archive from the borg repository and stop the borgmatic container afterwards. Check the [borgmatic](https://torsion.org/borgmatic/docs/how-to/extract-a-backup/) manual for details, but a possible command might be:
```
docker exec borgmatic borgmatic extract --archive ARCHIVE\_NAME
docker-compose down
```
4. Start all services using `docker-compoes up -d`.

## Cron Strategy
The borgmatic container is configured to schedule backups depending on the cron-file within the container. In order to stop the other services before executing borgmatic, one needs to bind mount docker sockets into the borgmatic container and configure [hooks](https://torsion.org/borgmatic/docs/how-to/add-preparation-and-cleanup-steps-to-backups/) to stop and restart the other services. However, this is considered a security risk.

Another option is to schedule backups using crond on the host. A simple cron-file might look like this:
```
cd /opt/docker/home-server-seafile  # Change to your base directory
docker exec seafile /scripts/gc.sh
docker-compose down
docker-compose up -d borgmatic
docker exec borgmatic bash -c "/scripts/run.sh 2>&1"
docker-compose up -d
```
