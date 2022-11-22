#######################################################################################
# Present NAS storage to Backblaze client via Wine                                    #
# For Ubuntu Server / Debian Server                                                   #
# David Harrop                                                                        #
# November 2022                                                                       #
#######################################################################################

# Assumes Ubuntu server 22.04 installed

sudo apt-get update
sudo apt-get install ubuntu-desktop-minimal --no-install-recommends open-vm-tools-desktop gnome-startup-applications -y
sudo reboot

# Optionally install Google Chrome:
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb # dependency errors will show, fixed with following command
sudo apt -f install

# Add AU locale for correct file time and date formats
sudo sed -i -e 's/en_US.UTF-8 UTF-8/# en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i -e 's/# en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen
sudo dpkg-reconfigure --frontend=noninteractive locales 
sudo localectl set-locale en_AU.UTF-8
reboot or re-login
# check date format is correct
date +%x

# Wine Setup
sudo dpkg --add-architecture i386 
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources # check your Linux distro and adjust ie Jammy
sudo apt update
sudo apt install --install-recommends winehq-stable -y
sudo apt-get install -y curl wget software-properties-common gnupg2 winbind xvfb winetricks -y

sudo apt-get clean -y
sudo apt-get autoremove -y
rm google-chrome-stable_current_amd64.deb
# Wine configuration
# Log in to the desktop gui and run: 
winecfg 
## IMPORTANT - you must follow these steps in order before going further!!: 
#	1. Wine gui installer will continue. 
#		2. When complete Wine configurator will launch
# 			3. Keep as Windows 7 version environment 
#			4. Configure local windows disk resources from NAS directories under "drives"	
#			(Drives must be configured before backblaze client install runs!!)

#Set the wine env
WINEPREFIX=~/.wine/drive_c

# create the below script with:
nano ~/backblaze_upload.sh 

#
#!/bin/sh
set -x
if [ -f "/home/$USER/.wine/drive_c/Program Files (x86)/Backblaze/bzbui.exe" ]; then
    wine64 "/home/$USER/.wine/drive_c/Program Files (x86)/Backblaze/bzbui.exe" -noqiet &
    sleep infinity
else
    cd ~/.wine/drive_c
    curl -L "https://www.backblaze.com/win32/install_backblaze.exe" --output "install_backblaze.exe"
    ls -la
    wine64 "install_backblaze.exe" &
    sleep infinity
fi

# make script executable
chmod +x backblaze_upload.sh

# Run the script FROM THE DESKTOP GUI TERMINAL
./backblaze_upload.sh
# Backblaze client will download, Login to the client to continue (screen sometimes does not refresh) and click install. 
# To run the Backblaze client subsequently, run the above script again, or set the script up as startup application in the Ubuntu gui
# and then enable automatic login via settings | users

# Clean up
rm ~/.wine/drive_c/install_backblaze.exe

# Add backblaze downloader script (download from Backblaze site and extract to ~/.wine/drive_c
nano ~/bzdownloader.sh 
chmod +x bzdownloader.sh

#!/bin/sh
cd ~/.wine/drive_c/backblaze_downloader
wine64 "bzdownloader.exe"