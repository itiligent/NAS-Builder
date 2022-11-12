#!/bin/bash
#######################################################################################
# Build a simple NAS with Samba & Rclone cloud sync 		                          #
# For Ubuntu / Debian                                                                 #
# David Harrop                                                                        #
# November 2022                                                                       #
#######################################################################################

# Instructions
# 1. Install Linux and mount/configure any extra disk or partition spaces you wish to use for storage
# 2. Either stay with the initial Linux user account created at install, or create a new
#    sudo user that Rclone will run as. A specific user account is needed becasue interactive (or user crontab tasks)
#    need rights to the rclone.conf user configuarion profile to run.
# 3. Run this install script logged on as the user you wish Rclone to run as.  
#	 - Samba is first installed and the current user is enabled for samba and then added to the a new sambausers group
# 	 - Next share directories are created in the paths as per $PRIVSHARE $PUBSHARE and $VFSSHARE variables
#    - Correct file permissions are set on the new share directories
#    - The preconfigured samba.conf file is copied over 
#    - The rclone.conf placeholder is created in $RCLONE_CONFIG_PATH and correct user permissions to it are set. 
#    - Rclone VFS is created as a system service and mounted in the $VFSSHARE path
#    - Samba and Rclone services are restarted
#	 - WSDD2 to enable network browsing is installed last. (This order seems to work better at discovering the finished samba config)   
	 
# 4. Investigate the correct settings you will need to authenticate with your cloud storage provider. 
#    See https://rclone.org for all other Rclone cloud sync options and instructions.
# 5. Run rclone config and follow the interactive prompts that relate to your specific cloud provider
# 6. Restart the preconfigured VFS cache service with systemctl start rclonevfs.service. 

#    Note1: Additional logging options to the $SYSTEMD_PATH/rclonevfs.service will help with any specific troubleshooting.
#    Log optionas are DEBUG, INFO, NOTICE & ERROR 
#    The below to rclonevfs.service to enables logging to syslog with resonable verbosity
#    --log-level INFO \ 
 
#    Note2: Many config options exist for setup and performance of VFS caching for many different use cases. 
#           The settings in this script configures $SYSTEMD_PATH/rclonevfs.service for "full cache mode". 
#           In this mode all reads and writes are buffered to and from disk. When data is read from the remote 
#           this is buffered to disk as well. This mode consumes the most bandwidth and storage space however 
#           it behaves similarly to a regular OneDrive client. 
# 			See https://rclone.org/commands/rclone_mount/#vfs-file-caching for all VFS config options


# Check for sudo
if [ -z "$SUDO_USER" ]; then
    echo "This script is only allowed to run from sudo";
    exit -1;
fi

clear

# Set variables
PASS=password
PRIVSHARE=/mnt/data/private_share
PUBSHARE=/mnt/data/public_share
VFSSHARE=/mnt/data/onedrive_vfs
SAMBA_CONFIG_PATH=/etc/samba
RCLONE_CONFIG_PATH=/home/$SUDO_USER/.config/rclone 
RCLONE_CACHE_PATH=/mnt/data/.rclone
SYSTEMD_PATH=/etc/systemd/system
INTERFACE=$(ip -br l | awk '$1 !~ "lo|vir|wl" { print $1}')
HOSTS_ALLOWED=$(ip -o -f inet addr show $INTERFACE | awk '/scope global/ {print $4}' | perl -ne 's/(?<=\d.)\d{1,3}(?=\/)/0/g; print;')

# Install packages
apt-get update
apt-get install samba -y
apt-get install acl -y
apt-get install wsdd2 -y

sudo -v ; curl https://rclone.org/install.sh | sudo bash

# Create the rclone config file with correct cuurrent user permissions
mkdir -p $RCLONE_CONFIG_PATH
sleep 2
touch $RCLONE_CONFIG_PATH/rclone.conf
sleep 2
chown -R $SUDO_USER:$SUDO_USER $RCLONE_CONFIG_PATH/rclone.conf

# Setup the current logged on linux user as a samba user then add this user to a new "sambausers" security group
(echo $PASS; sleep 1; echo $PASS) | smbpasswd -a -s $SUDO_USER
groupadd sambausers
gpasswd -a $SUDO_USER sambausers

# Create new share directories 
mkdir -p $PRIVSHARE
mkdir -p $PUBSHARE
mkdir -p $VFSSHARE

# Set Permissions on new share directories
sudo setfacl -R -m "g:sambausers:rwx" $PRIVSHARE
sudo setfacl -R -m "u:nobody:rwx" $PUBSHARE
sudo setfacl -R -m "u:$SUDO_USER:rwx" $VFSSHARE

cat <<EOF | sudo tee $SAMBA_CONFIG_PATH/smb.conf
#======================= Global Settings =======================
[global]

  workgroup = WORKGROUP
  server string = %h

  interfaces = 127.0.0.0/8 $INTERFACE
  bind interfaces only = yes

  log file = /var/log/samba/log.%m
  max log size = 1000
  logging = file
  panic action = /usr/share/samba/panic-action %d

  server role = standalone server
  obey pam restrictions = yes
  unix password sync = yes
  passwd program = /usr/bin/passwd %u
  passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
  pam password change = yes
  map to guest = bad user
  guest account = nobody
  usershare max shares = 0

#======================= Share Definitions =======================
[Private_Share]
   comment = Private LAN Storage
   path = $PRIVSHARE
   browseable = yes
   read only = no
   create mask = 0770
   directory mask = 0770
   valid users = @sambausers
   guest ok = no
   hosts allow = 127.0.0.1/8 $HOSTS_ALLOWED 

[Public_Share]
   comment = Public LAN Storage
   path = $PUBSHARE
   public = yes
   browseable = yes
   writeable = yes
   guest only = yes
   create mask = 0777
   directory mask = 0777
   hosts allow = 127.0.0.1/8 $HOSTS_ALLOWED

[OneDrive_VFS]
   comment = Virtual OneDrive
   path = $VFSSHARE
   browseable = yes
   read only = no
   create mask = 0770
   directory mask = 0770
   valid users = $SUDO_USER
   guest ok = no
   hosts allow = 127.0.0.1/8 $HOSTS_ALLOWED
EOF

# Below is for onedrive personal and is intended as a placeholer only. 
# You will need to run 'rclone config' after this installer script to correctly complete the Rclone setup for your cloud provider.
cat <<EOF > $RCLONE_CONFIG_PATH/rclone.conf
[onedrive-personal]
type = onedrive
client_id = ???
client_secret = ???
region = global
token = {"??"}
drive_id = ???
drive_type = personal
chunk_size = 320k
EOF

# Create the Rclone VFS system service
cat <<"EOF" > $SYSTEMD_PATH/rclonevfs.service
[Unit]
Description=One Drive VFS Mount (rclone)
AssertPathIsDirectory=/mnt/data/onedrive_vfs
After=multi-user.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount \
        --config=path_to_rclone.conf/rclone.conf \
        --cache-tmp-upload-path=path_to_rclone_cache \
        --cache-db-path=path_to_rclone_cache \
        --cache-dir=path_to_rclone_cache/.rclone \
        --cache-chunk-size 8m \
        --cache-chunk-total-size 10g \
        --cache-info-age 12h \
        --cache-tmp-wait-time 30s \
        --dir-cache-time 5m \
        --vfs-cache-mode full \
        --vfs-cache-max-age 1h \
        --vfs-read-chunk-size 128m \
        --vfs-read-ahead 512m \
        --vfs-read-chunk-size-limit 0 \
        --cache-db-wait-time 0m3s \
        --buffer-size 256m \
        --allow-other \
        --uid 1000 onedrive-personal:/ path_to_vfs_root
ExecStop=/bin/fusermount -u path_to_vfs_root
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

# Adjust rclonevfs.service file as required backslashes make it hard to write out in one pass
sed -i "s|path_to_rclone.conf|$RCLONE_CONFIG_PATH|g" $SYSTEMD_PATH/rclonevfs.service
sed -i "s|path_to_rclone_cache|$RCLONE_CACHE_PATH|g" $SYSTEMD_PATH/rclonevfs.service
sed -i "s|path_to_vfs_root|$VFSSHARE|g" $SYSTEMD_PATH/rclonevfs.service

# List all samba users to verify new samba user creation
pdbedit -L -v

# start rclone VFS as a service
systemctl enable rclonevfs.service
systemctl start rclonevfs.service
systemctl restart smbd nmbd
systemctl restart wsdd2

# Add fix for potential race condition where wsdd2 starts before Samba or DHCP network adapter is fully initialised
crontab -l > cron_1
echo "@reboot sleep 30 && systemctl restart wsdd2 # restart wsdd2 30 sec after reboot" >> cron_1
crontab cron_1
rm cron_1