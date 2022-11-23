#!/bin/bash

# Prevent rclone scripts being run simultaneously or continuing as zombies
# Lauch scheduled rclone scripted tasks via this script to first validate if a particular
# sheduled script is already/still running, then kill it before re-running. This will prevent 
# mutiple rclone processes accumulating and causing issies with upstream connection limits etc.    
 
# Which rclone script to check is already running?
SYNC_SCRIPT_CHECK_1=/home/$USER/.config/rclone/rclone-sync-onedrive.sh
#SYNC_SCRIPT_CHECK_2=/home/$USER/.config/rclone/some-other-rclone-task.sh

# Kill any script processes that are already running (or rclone zombies)
PID=`ps aux | grep $SYNC_SCRIPT_CHECK | awk '{print $2}'`

for P in $PID; do
    echo "Killing $P"
    kill -9 $P
echo terminating
done

# Run the rclone script
$SYNC_SCRIPT_CHECK_1
#$SYNC_SCRIPT_CHECK_1