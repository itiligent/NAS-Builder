#######################################################################################
# Present NAS storage to Backblaze client via Docker (with web browser client access) #
# For Ubuntu Server / Debian Server                                                   #
# David Harrop                                                                        #
# November 2022                                                                       #
#######################################################################################


# Add AU locale for correct file time and date formats
sudo sed -i -e 's/en_US.UTF-8 UTF-8/# en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i -e 's/# en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen
sudo dpkg-reconfigure --frontend=noninteractive locales 
sudo localectl set-locale en_AU.UTF-8
reboot or re-login


#Install Docker

!/bin/bash
timedatectl set-timezone Australia/Melbourne
sudo apt update
sudo apt-get install ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
		$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
sudo usermod -aG docker $SUDO_USER
newgrp docker
 
# then manually run

docker run \
    -p 80:5800 \
	-e "DISPLAY_WIDTH=657" \
	-e "DISPLAY_HEIGHT=473" \
    --init \
	--restart unless-stopped \
	--name backblaze_personal_backup \
    -v '/mnt/data/:/drive_d/' \
    -v '/home/david/.wine:/config/' \
    tessypowder/backblaze-personal-wine:latest
	
Next go your browser http://NAS.ip and click install wine, then STOP. 

IMPORTANT: before continuing with the Backblaze install:

	You musr you MUST setup wine dosdisks FIRST.. keping the first terminal with docker run open, from a second terminal:
	
	docker exec --user app backblaze_personal_backup ln -s /drive_d/ /config/wine/dosdevices/d:
	docker restart backblaze_personal_backup
	
	then go back to browser http://NAS.ip reresh and continue Backblaze login and install 



