#######################################################################################
# Present NAS storage as a local OS disk via virtio-fs/KVM/Qemu hypervisor            #
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

# If host system is VMware, ensure VMware ESXi is configured with Virutalisation CPU extensions are enabled for the VM

sudo apt-get update
sudo apt-get install ubuntu-desktop-minimal --no-install-recommends open-vm-tools-desktop -y

reboot

sudo apt-get install qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager -y

reboot

# Optionally install Google Chrome:
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
sudo apt -f install
 
# To connect VMs directly to the local network without NAT, setup a network bridge in both Linux and Qemu 
# 	If host system is Esxi, Vmware vswitch security must allow promiscous mode, MAC address changes & forged transmits for bridging to work
# 	If you have already configured Samba you will need to add the new br0 interface to the global section of the smb.conf file

# /etc/netplan/filename.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens160:
     optional: true
     dhcp4: yes
  bridges:
    br0:
      interfaces: [ens160]
      macaddress: 00:0C:29:AB:05:51  # add your desired mac to set a static dhcp lease
      dhcp4: yes

sudo netplan generate
sudo netplan --debug apply

reboot

# Create new "host-bridge" network in Qemu  
sudo nano /etc/libvirt/qemu/host-bridge.xml

<network>
  <name>host-bridge</name>
  <forward mode="bridge"/>
  <bridge name="br0"/>
</network>

# Then write the config to Qemu and verify...
virsh net-define /etc/libvirt/qemu/host-bridge.xml
virsh net-start host-bridge
virsh net-autostart host-bridge
virsh net-list --all

# Google for rest of VM with virtio-fs setup in Virtmanager. Detailed instructions for setting up a virtio-fs in a VM:
# Need to download 
# 	1. virtio-win driver iso
# 	3. spice guest tools
# 	3. winfsp application (needed for file system pass through only)
https://virtio-fs.gitlab.io/howto-windows.html
https://winfsp.dev/
https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md
https://www.spice-space.org/download.html
http://www.linux-kvm.org/page/9p_virtio
	
# Lastly, configure VM in Virtmanager (or directly edit XML via cli) to use the new "host-bridge" as a network source device, 
# also select VM's network device model as = virtio 

# With VMss running, here are some useful virt commands
	virsh list --all
	virsh domblklist guest_name # get images file location of VM
	virsh dumpxml target_guest_machine > ~/target_guest_machine.xml
	sudo qemu-img convert -O qcow2 source.qcow2 shrunk.qcow2 -p
	virsh define guest_name.xml
	virsh shutdown target_guest_machine
	virsh autostart vm_machine_name --disable or --enable
	virsh snapshot-create-as --domain {VM-NAME} --name "{SNAPSHOT-NAME}"
