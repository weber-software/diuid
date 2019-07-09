#!/bin/bash

#start sshd
/etc/init.d/ssh start

# Create the ext4 volume image if DISK is set
if [[ -n "${DISK}" ]] ; then
    dd if=/dev/zero of=/var/tmp/docker.img bs=1 count=0 seek=${DISK}
    mkfs.ext4 /var/tmp/docker.img
fi

#start the uml kernel with docker inside
/sbin/start-stop-daemon --start --background --make-pidfile --pidfile /tmp/kernel.pid --exec /bin/bash -- -c "exec /kernel.sh > /tmp/kernel.log 2>&1"

echo -n "waiting for dockerd "
while true; do
	if docker info 2>/dev/null >/dev/null; then
		echo ""
		break
	fi
	if ! /sbin/start-stop-daemon --status --pidfile /tmp/kernel.pid; then
		echo ""
		echo failed to start uml kernel:
		cat /tmp/kernel.log
		exit 1
	fi

	echo -n "."
	sleep 0.5
done

exec "$@"

