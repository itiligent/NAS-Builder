#!/bin/bash
#######################################################################################
# Build a KVM/Qemu virtutal machine hosting platform   		                          #
# For Ubuntu / Debian                                                                 #
# David Harrop                                                                        #
# November 2022                                                                       #
#######################################################################################

# KVM is a linux hypervisor that is very userful to turn your NAS into a hyperconverged 
# server. If you need to run other OS, containers or utilities that also need direct 
# access to your host's disk filesystem, setup virtio-fs in each VM to pass through NAS
# disk storage to the guest VM as a local disk. Very useful for defeating software that
# enforces lmitations on accessing or or usuing removable shared storage  (Onedrive, Backblaze etc)

# https://virtio-fs.gitlab.io/howto-windows.html
# https://winfsp.dev/
# https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md
# https://www.spice-space.org/download.html
# http://www.linux-kvm.org/page/9p_virtio

# If running in vmware check "Expose hardware assisted virtualization to the guest OS" under ESXI VM CPU settings) 
apt-get apt update
apt-get install ubuntu-desktop-minimal --no-install-recommends open-vm-tools-desktop -y
apt-get install qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager -y
timedatectl set-timezone Australia/Melbourne

# Useful virt commands
# virsh list --all
# virsh shutdown target_guest_machine
# virsh domblklist guest_name # get images file location of VM
# virsh dumpxml target_guest_machine > ~/target_guest_machine.xml
# sudo qemu-img convert -O qcow2 source.qcow2 shrunk.qcow2 -p
# virsh define guest_name.xml
