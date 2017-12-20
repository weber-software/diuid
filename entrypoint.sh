#!/bin/bash

#start sshd
/etc/init.d/ssh start

# Create the ext4 volume image
dd if=/dev/zero of=/var/tmp/docker.img bs=1 count=0 seek=${DISK}
mkfs.ext4 /var/tmp/docker.img

#start the uml kernel with docker inside
TMPDIR=/dev /sbin/start-stop-daemon --start --chuid `whoami` --chdir $PWD --background --make-pidfile --pidfile /tmp/kernel.pid --exec /linux/linux -- \
 rootfstype=hostfs rw quiet eth0=slirp,,/usr/bin/slirp-fullbolt mem=$MEM init=/init.sh

echo -n "waiting for dockerd "
while true; do
	if docker info 2>/dev/null >/dev/null; then
		echo ""
		break
	fi
	echo -n "."
	sleep 0.5
done

#if [ $# -eq 0 ]; then
	#/bin/bash
#else
	#/bin/bash -c "$@"
#fi

exec "$@"

#stop the uml kernel
/sbin/start-stop-daemon --stop --pidfile /tmp/kernel.pid