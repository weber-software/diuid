#!/bin/bash
set -eux -o pipefail

export DOCKER_BUILDKIT=1

docker build -t diuid .

time docker run --cap-add=SYS_PTRACE --rm diuid docker echo "measuring kernel+daemon start-up time"

time docker run --cap-add=SYS_PTRACE --rm diuid docker run hello-world
