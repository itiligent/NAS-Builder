# NAS-Builder
## Build a Linux & Samba NAS with Rclone sync to cloud storage

### Optionally: Present NAS as a local disk to applications which do not support NAS or Linux. 

Various cloud storage clients or cloud backup utilities are limited to only allow **local disk access** for Windows or Mac or do not support Linux.
To circumvent application limitations on accessing shared storage, a workaround is to add a layer above the NAS storage and to pass this through to 
either an internal hypervisor with a Windows VM using virtio-fs, a Windows application running in Wine, or a purpose built Docker application.
Methods for each approach are included
