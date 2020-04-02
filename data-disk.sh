#!/bin/bash

mkdir -p /mnt/disks/data

local_ssds=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/local_ssds)

if [ "$local_ssds" = "0" ]; then
  if ! mount -o discard,defaults /dev/disk/by-id/google-data /mnt/disks/data; then \
      mkfs.xfs -f -q /dev/disk/by-id/google-data;\
      mount -o discard,defaults /dev/disk/by-id/google-data /mnt/disks/data;\
      mkdir -p /mnt/disks/data/scylla/data /mnt/disks/data/scylla/commitlog;\
      chown -R scylla:scylla /mnt/disks/data/scylla;\
      scylla_io_setup;
  fi;
else
  if ! mount -o discard,defaults /dev/md0 /mnt/disks/data; then \
      mdadm_cmd="mdadm --create /dev/md0 --level=0 --raid-devices=$local_ssds";\
      for (( i=1; i<=$local_ssds; i++ )); do mdadm_cmd+=" /dev/nvme0n$i"; done;\
      $mdadm_cmd;\
      mkfs.xfs -f -q /dev/md0;\
      mount -o discard,defaults /dev/md0 /mnt/disks/data;\
      mkdir -p /mnt/disks/data/scylla/data /mnt/disks/data/scylla/commitlog;\
      chown -R scylla:scylla /mnt/disks/data/scylla;\
      echo UUID=`blkid -s UUID -o value /dev/md0` /mnt/disks/data xfs discard,defaults,nofail 0 2 | tee -a /etc/fstab
      scylla_io_setup;
  fi;
fi

grep SEASTAR /etc/scylla.d/io.conf | grep -q 'max-io-requests=1' && scylla_io_setup
