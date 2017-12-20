#!/bin/bash

mount -t proc proc /proc/
mount -t sysfs sys /sys/
mount -t tmpfs none /run
mkdir /dev/pts
mount -t devpts devpts /dev/pts
rm /dev/ptmx
ln -s /dev/pts/ptmx /dev/ptmx
mkdir -p /var/lib/docker/
if [[ -f /var/tmp/docker.img ]] ; then
    mount -t ext4 /var/tmp/docker.img /var/lib/docker/
else
    mount -t tmpfs none /var/lib/docker/
fi

ip link set dev lo up
ip link set dev eth0 up
route add default dev eth0
ifconfig eth0 10.0.2.15

/etc/init.d/cgroupfs-mount start
PATH=$PATH:/usr/bin/ start-stop-daemon --start --background --no-close --exec /usr/bin/dockerd --pidfile /var/run/docker-ssd.pid --make-pidfile -- -p /var/run/docker.pid --storage-driver=overlay2 -H 0.0.0.0:2375 >> /var/log/docker.log 2>&1

#connect to the parent docker container for reverse tcp forwarding of the docker socket
ssh -o StrictHostKeyChecking=no -R2375:127.0.0.1:2375 10.0.2.2

ret=$?
if [ $ret -ne 0 ]; then
	exit 1
fi
/sbin/halt -f