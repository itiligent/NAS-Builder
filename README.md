# NAS-Builder
## Build a Linux & Samba NAS with Rclone sync to cloud storage

### Optionally: Present NAS as a local disk for applications which do not support NAS. 

Various cloud storage clients or cloud backup utilities are limited to only allow local disk access. 
Passing NAS storage through to either a hypervisor with virtio-fs, Wine or a Docker application, these 
application limitations can be circumvented.
