#!/bin/bash
set -eux -o pipefail

docker build -t diuid .

time docker run --rm diuid docker echo "measuring kernel+daemon start-up time"

time docker run --rm diuid docker run hello-world