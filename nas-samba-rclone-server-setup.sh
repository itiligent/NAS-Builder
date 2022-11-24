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
    echo "You must run this script as sudo!";
    exit -1;
fi

clear

# user specific variables
PRIVSHARE=/mnt/data/private_share
PUBSHARE=/mnt/data/public_share
VFSSHARE=/mnt/data/onedrive_vfs
RCLONE_CACHE_PATH=/mnt/data/.rclone
SMBPASS=password
RCLONE_REMOTE_NAME=rclone_remote_connection

# platform variables
SAMBA_CONFIG_PATH=/etc/samba
RCLONE_CONFIG_PATH=/home/$SUDO_USER/.config/rclone 
SYSTEMD_PATH=/etc/systemd/system
INTERFACE=$(ip -br l | awk '$1 !~ "lo|vir|wl" { print $1}')
HOSTS_ALLOWED=$(ip -o -f inet addr show $INTERFACE | awk '/scope global/ {print $4}' | perl -ne 's/(?<=\d.)\d{1,3}(?=\/)/0/g; print;')


# Install packages
apt-get update
apt-get install curl samba acl wsdd2 -y
sudo -v ; curl https://rclone.org/install.sh | sudo bash

# Create the rclone config file with correct cuurrent user permissions
sudo -u $SUDO_USER mkdir -p $RCLONE_CONFIG_PATH   
sudo -u $SUDO_USER touch $RCLONE_CONFIG_PATH/rclone.conf

# Setup the current logged on linux user as a samba user then add this user to a new "sambausers" security group
(echo $SMBPASS; sleep 1; echo $SMBPASS) | smbpasswd -a -s $SUDO_USER
groupadd sambausers
gpasswd -a $SUDO_USER sambausers

# Create new share directories 
mkdir -p $PRIVSHARE
mkdir -p $PUBSHARE
mkdir -p $VFSSHARE
# Optionally chang the default permissions on the share directors to avoid permissions issues when moving files around from Linux command as sudo
chown -R $SUDO_USER:$SUDO_USER $PRIVSHARE
chown -R $SUDO_USER:$SUDO_USER $PUBSHARE
chown -R $SUDO_USER:root $VFSSHARE

# Set Permissions on new share directories
sudo setfacl -R -m "g:sambausers:rwx" $PRIVSHARE
sudo setfacl -R -m "u:nobody:rwx" $PUBSHARE
sudo setfacl -R -m "u:$SUDO_USER:rwx" $VFSSHARE

cat <<EOF | sudo tee $SAMBA_CONFIG_PATH/smb.conf
#======================= Global Settings =======================
[global]

  workgroup = WORKGROUP
  server string = Samba Server %h

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

# Add fix for potential race condition where wsdd2 starts before Samba or DHCP network adapter is fully initialised
crontab -l > cron_1
echo "@reboot sleep 30 && systemctl restart wsdd2 # restart wsdd2 30 sec after reboot" >> cron_1
crontab cron_1
rm cron_1

# Set correct locale for easy to read file time/date formats
update-locale "en_AU.UTF-8"
locale-gen --purge "en_AU.UTF-8"
dpkg-reconfigure --frontend noninteractive locales
localectl set-locale en_AU.UTF-8
timedatectl set-timezone Australia/Melbourne


# Below is for onedrive personal and is intended as a placeholer only. 
# You will need to run 'rclone config' after this installer script to correctly complete the Rclone setup for your cloud provider.
cat <<EOF > $RCLONE_CONFIG_PATH/rclone.conf
[$RCLONE_REMOTE_NAME]
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
AssertPathIsDirectory=path_to_vfs_root
After=multi-user.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount \
        --config=path_to_rclone.conf/rclone.conf \
        --cache-tmp-upload-path=path_to_rclone_cache \
        --cache-db-path=path_to_rclone_cache \
        --cache-dir=path_to_rclone_cache \
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
        --uid 1000 remote_name:/ path_to_vfs_root
ExecStop=/bin/fusermount -u path_to_vfs_root
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

# Quick and dirty adjustment to rclonevfs.service because backslashes are cat escape characters. 
# We need to use "EOF" in quotes to force exact text append, but this also means $VARIABLES become plain text too. 
# So, instead we use sed to put back the variable values that should be translated...
sed -i "s|path_to_rclone.conf|$RCLONE_CONFIG_PATH|g" $SYSTEMD_PATH/rclonevfs.service
sed -i "s|path_to_rclone_cache|$RCLONE_CACHE_PATH|g" $SYSTEMD_PATH/rclonevfs.service
sed -i "s|path_to_vfs_root|$VFSSHARE|g" $SYSTEMD_PATH/rclonevfs.service
sed -i "s|remote_name|$RCLONE_REMOTE_NAME|g" $SYSTEMD_PATH/rclonevfs.service


# Kickstart all services 
systemctl restart smbd nmbd
systemctl restart wsdd2
systemctl enable rclonevfs.service
systemctl start rclonevfs.service

# Setup structure to call rclone scripts  
cat <<"EOF" > $RCLONE_CONFIG_PATH/run-rclone-script.sh
#!/bin/bash

# Prevent scheduled rclone scripted tasks being run multiple times simultaneously if they are triggered again before the previous is complete.
# Also we must prevent rclone continuing as a zombie process even after an rclone task has been manually stopped with ^C (a commmon issue in some circumstances)

# Instead, we should hand launch or cron schedule all scripted rclone tasks via this caller script. 

# This script first validates if a particular scheduled rclone script is still running, then kills it before re-running same.
# You can confirm how many instances of a script are running at any time with..
# ps aux | grep rclone 

 
# Which rclone script do we check to see is already running?
SYNC_SCRIPT_CHECK_1=script_1
#SYNC_SCRIPT_CHECK_2=script_2


# Make a list of any PIDs that contain the term "rclone" that are running. Place any extra exceptions below. Be careful using "rclone" other script names. try r-clone
PID=`ps aux | grep "rclone" | grep -v 'grep' | grep -v 'mount' | grep -v 'nano' | grep -v 'run-rclone-script.sh' | awk '{ print $2 }'`
#PID=`ps aux | grep some-other-string | awk '{print $2}'` # for later if needed

# Now lets kill all of the PIDs from the list
for P in $PID; do
    echo "Killing $P"
    kill -9 $P
done

# Now that we've stopped the rclone we dont want to duplicate, we can start the same script(s) again
script_path/$SYNC_SCRIPT_CHECK_1
#script_path/$SYNC_SCRIPT_CHECK_2 # for later if needed
EOF

chmod +x $RCLONE_CONFIG_PATH/run-rclone-script.sh
chown $SUDO_USER:$SUDO_USER $RCLONE_CONFIG_PATH/run-rclone-script.sh

sed -i "s|script_1|sync-$RCLONE_REMOTE_NAME.sh|g" $RCLONE_CONFIG_PATH/run-rclone-script.sh
sed -i "s|script_2|some-other-rclone-script.sh|g" $RCLONE_CONFIG_PATH/run-rclone-script.sh
sed -i "s|script_path|$RCLONE_CONFIG_PATH|g" $RCLONE_CONFIG_PATH/run-rclone-script.sh

# 
cat <<EOF > $RCLONE_CONFIG_PATH/sync-$RCLONE_REMOTE_NAME.sh
#!/bin/bash
# This example DOWNLOADS from cloud storage, syncs to a local share and writes error level output to a logfile (change ERROR to INFO or DEBUG for differing output)
# The below settings are very conservative and do not appear to trigger any bannning or errors from a OneDrive Personal remote connection.
# See rclone docs for more info on tuning cloud provider connections and avoiding a breach of provider transaction & connection limits. (Breaching limits can invoke upstream throttling or even periodic disconnections)
 
rclone sync --tpslimit 3  --tpslimit-burst 1 --transfers=3 $RCLONE_REMOTE_NAME: $PRIVSHARE --log-level ERROR --log-file $PRIVSHARE/rclone.log --stats-one-line

# EXAMPLE manual commmand - DOWNLOADS from cloud and syncs to a local share showing info output in the terminal)
#rclone sync -v --tpslimit 3  --tpslimit-burst 1 --transfers=3 $RCLONE_REMOTE_NAME: $PRIVSHARE --stats-one-line 
EOF

chmod +x $RCLONE_CONFIG_PATH/sync-$RCLONE_REMOTE_NAME.sh
chown $SUDO_USER:$SUDO_USER $RCLONE_CONFIG_PATH/sync-$RCLONE_REMOTE_NAME.sh


# Setup a (disabled) example cron task (in current user's crontab) to regularly run a scripted rclone task 
su -s /bin/bash -c 'crontab -l > cron_2' -m $SUDO_USER
echo "#0 */12 * * * $RCLONE_CONFIG_PATH/run-rclone-script.sh # run this rclone task every 12 hours" >> cron_2
su -s /bin/bash -c 'crontab cron_2' -m $SUDO_USER
rm cron_2


