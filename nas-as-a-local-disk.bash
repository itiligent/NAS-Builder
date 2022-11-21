#######################################################################################
# Build a flexible VM, Wine or docker local disk layer above Linux NAS storage              #
# For Ubuntu Server / Debian Server                                                   #
# David Harrop                                                                        #
# November 2022                                                                       #
#######################################################################################


#######################################################################################
# Hypervisor and VM solution: (KVM & QEMU Libvirt)
#	If host system is VMware, ensure VMware ESXi is configured with Virutalisation CPU extensions are enabled for the VM

timedatectl set-timezone Australia/Melbourne	
apt-get apt update
apt-get install ubuntu-desktop-minimal --no-install-recommends open-vm-tools-desktop -y
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
sudo apt -f install
apt-get install qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager -y
# Google for rest of VM with virtio-fs setup in Virtmanager. Detailed instructions for setting up a virtio-fs in a VM:
https://virtio-fs.gitlab.io/howto-windows.html
https://winfsp.dev/
https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md
https://www.spice-space.org/download.html
http://www.linux-kvm.org/page/9p_virtio
 
# To connect VMs directly to the local network without NAT, setup a network bridge in both Linux and libvirt 
# 	If host system is VMware, vswitch security must allow promiscous mode, MAC address changes & forged transmits for bridging to work

# /etc/netplan/filename.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens160:
      dhcp4: yes
  bridges:
    br0:
      interfaces: [ens160]
      macaddress: 00:0C:29:AB:05:51 # add your desired mac to set a static dhcp lease
      dhcp4: yes

sudo netplan generate
sudo netplan --debug apply

# Create new "host-bridge" network in libvirt 
sudo nano /etc/libvirt/qemu/host-bridge.xml

<network>
  <name>host-bridge</name>
  <forward mode="bridge"/>
  <bridge name="br0"/>
</network>

# Then write the config and verify...
virsh net-define /etc/libvirt/qemu/host-bridge.xml
virsh net-start host-bridge
virsh net-autostart host-bridge
virsh net-list --all
	
# Lastly, configure VM in Virtmanager or XML cli to use the new "host-bridge" as a network source device, also select device model as = virtio 

# With VMss running, here are some useful virt commands
	virsh list --all
	virsh domblklist guest_name # get images file location of VM
	virsh dumpxml target_guest_machine > ~/target_guest_machine.xml
	sudo qemu-img convert -O qcow2 source.qcow2 shrunk.qcow2 -p
	virsh define guest_name.xml
	virsh shutdown target_guest_machine
	virsh autostart vm_machine_name --disable or --enable
	virsh snapshot-create-as --domain {VM-NAME} --name "{SNAPSHOT-NAME}"



#######################################################################################
# Backblaze Docker solution

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
			
	
