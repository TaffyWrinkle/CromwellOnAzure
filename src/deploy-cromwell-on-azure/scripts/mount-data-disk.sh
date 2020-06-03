#!/bin/bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

set -o errexit
set -o nounset
set -o errtrace

trap 'write_log "mount-data-disk failed with exit code $?"' ERR

readonly log_file="/tmp/mount-data-disk.log"
touch $log_file
exec 1>>$log_file
exec 2>&1

function write_log() {
    # Prepend the parameter value with the current datetime, if passed
    echo ${1+$(date --iso-8601=seconds) $1}
}

write_log "mount-data-disk starting"

if ! blkid | grep -q "dev/sdc1" ; then
    write_log "Formatting data disk /dev/sdc"
    sudo fdisk /dev/sdc <<EOF
n
p
1
2048
67108863
p
w
EOF

    write_log "Creating file system at /dev/sdc1"
    sudo mkfs -t ext4 /dev/sdc1
fi

if ! df /dev/sdc1 | grep -q "/data" ; then
    write_log "Mounting /dev/sdc1 to /data"
    sudo mkdir -p /data
    sudo mount /dev/sdc1 /data
fi

if ! grep -q "/data" /etc/fstab ; then
    write_log "Adding /data to fstab"
    DISKUUID=$(sudo blkid /dev/sdc1 -s UUID -o value)
    sudo su -c "echo 'UUID=$DISKUUID   /data   ext4   defaults,nofail   1   2' >> /etc/fstab"
fi

write_log "mount-data-disk complete"
