#!/bin/bash

echo "Configuration: MEM=$MEM DISK=$DISK"

#start sshd
/etc/init.d/ssh start

# Create the ext4 volume image for /var/lib/docker
if [ ! -f /persistent/var_lib_docker.img ]; then
    echo "Formatting /persistent/var_lib_docker.img"
    dd if=/dev/zero of=/persistent/var_lib_docker.img bs=1 count=0 seek=${DISK} > /dev/null 2>&1
    mkfs.ext4 /persistent/var_lib_docker.img > /dev/null 2>&1
fi

# verify TMPDIR configuration
if [ $(stat --file-system --format=%T $TMPDIR) != tmpfs ]; then
    echo "For better performance, consider mounting a tmpfs on $TMPDIR like this: \`docker run --tmpfs $TMPDIR:rw,nosuid,nodev,exec,size=8g\`"
fi

#start the uml kernel with docker inside
echo "DIUID_DOCKERD_FLAGS=\"$DIUID_DOCKERD_FLAGS\"" > /tmp/env
/sbin/start-stop-daemon --start --background --make-pidfile --pidfile /tmp/kernel.pid --exec /bin/bash -- -c "exec /kernel.sh > /tmp/kernel.log 2>&1"

echo -n "waiting for dockerd "
while true; do
	if docker version 2>/dev/null >/dev/null; then
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

