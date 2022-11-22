#######################################################################################
# Present NAS storage to Backblaze client via Wine                                    #
# For Ubuntu Server / Debian Server                                                   #
# David Harrop                                                                        #
# November 2022                                                                       #
#######################################################################################

# Assumes Ubuntu server 22.04 installed

sudo apt-get apt update
sudo apt-get install ubuntu-desktop-minimal --no-install-recommends open-vm-tools-desktop -y
sudo reboot

# Optionally install Google Chrome:
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
sudo apt -f install


# Add AU locale for correct file time and date formats
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y locales
sudo sed -i -e 's/en_US.UTF-8 UTF-8/# en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i -e 's/# en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen
sudo dpkg-reconfigure --frontend=noninteractive locales 
sudo localectl set-locale en_AU.UTF-8
reboot or re-login

# Wine Setup
sudo dpkg --add-architecture i386 
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources # check your Linux distro and adjust ie Jammy
sudo apt update
sudo apt install --install-recommends winehq-stable -y
sudo apt-get install -y curl wget software-properties-common gnupg2 winbind xvfb winetricks gnome-startup-applications -y

sudo apt-get clean -y
sudo apt-get autoremove -y


# Log in to the desktop gui and run: 
winecfg  
#	Wine gui install will continue. 
#		When complete Wine configurator will launch
# 			Keep as Windows 7 version environment 
#			Configure local windows disk resources from NAS directories under "drives"

WINEPREFIX=~/.wine/drive_c

# create the below script with:
nano ~/run_backblaze.sh 
chmod +x run_backblaze.sh
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

# Clean up
rm ~/.wine/drive_c/install_backblaze.exe

# Run the script FROM THE DESKTOP GUI TERMINAL
./run_backblaze.sh
# Backblaze client will download and install. To run the Backblaze client subsequently 
# run the above script again, or set the script up as startup application in the Ubuntu gui
# and enable automatic login via settings | users

