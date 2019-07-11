#!/bin/bash
set -eux -o pipefail

docker build -t diuid .

time docker run --cap-add=SYS_PTRACE --rm diuid docker run hello-world
