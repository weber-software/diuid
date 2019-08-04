#!/bin/bash
set -xu
source /tmp/env

mount -t proc proc /proc/
mount -t sysfs sys /sys/
mount -t tmpfs none /run
mkdir /dev/pts
mount -t devpts devpts /dev/pts
rm /dev/ptmx
ln -s /dev/pts/ptmx /dev/ptmx

rngd -r /dev/urandom

mkdir -p /var/lib/docker/
mount -t ext4 /persistent/var_lib_docker.img /var/lib/docker/

ip link set dev lo up
ip link set dev eth0 up
route add default dev eth0
ifconfig eth0 10.0.2.15

/etc/init.d/cgroupfs-mount start

#connect to the parent docker container for reverse forwarding of the docker socket
ssh -f -N -o StrictHostKeyChecking=no \
    -R/var/run/docker.sock:/var/run/docker.sock \
    -R0.0.0.0:2375:127.0.0.1:2375 \
    -R0.0.0.0:2376:127.0.0.1:2376 \
    10.0.2.2

# Change group for docker.sock across DIUID_DOCKERD_FLAGS
docker_group='docker'
DIUID_DOCKERD_OPTS=`getopt -q -o G: --long group: -n 'getopt' -- $DIUID_DOCKERD_FLAGS`
eval set -- "$DIUID_DOCKERD_OPTS"
while true; do
  case "$1" in
	-G|--group ) docker_group="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

chmod 0660 /var/run/docker.sock && chown root:$docker_group /var/run/docker.sock

PATH=/usr/bin:$PATH dockerd --userland-proxy-path=$(which diuid-docker-proxy) -H unix:///var/run/docker.sock $DIUID_DOCKERD_FLAGS

ret=$?
if [ $ret -ne 0 ]; then
	exit 1
fi
/sbin/halt -f
