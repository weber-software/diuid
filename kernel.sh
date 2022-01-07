#!/bin/bash
set -eu -o pipefail
slirp4netns --target-type=bess /run/slirp4netns-bess.sock >/tmp/slirp4netns-bess.log 2>&1 &
exec /linux/linux rootfstype=hostfs rw vec0:transport=bess,dst=/run/slirp4netns-bess.sock,depth=128,gro=1 mem=$MEM init=/init.sh
