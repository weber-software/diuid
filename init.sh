#!/bin/bash
set -xue -o pipefail
source /tmp/env

mount -t proc proc /proc/
mount -t sysfs sys /sys/

# Initialize cgroup2 mount
mount -t cgroup2 none /sys/fs/cgroup
# Evacuate the current process to "init.tmp" group so that we can configure subtree_control
mkdir /sys/fs/cgroup/init.tmp
echo $$ >/sys/fs/cgroup/init.tmp/cgroup.procs
cat /sys/fs/cgroup/cgroup.controllers
echo '+cpu +io +memory +pids' >/sys/fs/cgroup/cgroup.subtree_control
# Restore the "init.tmp" group to the top-level group
echo $$ >/sys/fs/cgroup/cgroup.procs
rmdir /sys/fs/cgroup/init.tmp

mount -t tmpfs none /run
mkdir /dev/pts
mount -t devpts devpts /dev/pts
rm /dev/ptmx
ln -s /dev/pts/ptmx /dev/ptmx

rngd -r /dev/urandom

mkdir -p /var/lib/docker/
mount -t ext4 /persistent/var_lib_docker.img /var/lib/docker/

ip link set dev lo up
ip link set dev vec0 up
ip addr add 10.0.2.100/24 dev vec0
ip route add default via 10.0.2.2

#connect to the parent docker container for reverse forwarding of the docker socket
ssh -f -N -o StrictHostKeyChecking=no \
    -R/var/run/docker.sock:/var/run/docker.sock \
    -R0.0.0.0:2375:127.0.0.1:2375 \
    -R0.0.0.0:2376:127.0.0.1:2376 \
    10.0.2.2

# Change permissions to docker.sock to allow user access
chmod 0660 /var/run/docker.sock && chown root:$DIUID_DOCKERD_GROUP /var/run/docker.sock

PATH=/usr/bin:$PATH dockerd --userland-proxy-path=$(which diuid-docker-proxy) -H unix:///var/run/docker.sock $DIUID_DOCKERD_FLAGS

ret=$?
if [ $ret -ne 0 ]; then
	exit 1
fi
/sbin/halt -f
