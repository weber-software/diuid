[![Build Status](https://travis-ci.org/weber-software/diuid.svg?branch=master)](https://travis-ci.org/weber-software/diuid)

# Docker in User Mode Linux

An image for running a dockerd inside a user mode linux kernel.
This way it is possible to run and build docker images without forwarding the docker socket or using privileged flags.
Therefore this image can be used to build docker images with the gitlab-ci-multi-runner docker executor.

## How it works

It starts a user mode linux kernel with a dockerd inside.
The network communication is bridged by slirp.
I didn't managed to get the "redir" of slirp to work and so i'm forwarding the docker socket using reverse tunneling over an SSH connection from the uml kernel to the container.

## Security

Because uml linux is using ptrace the image might need to be started with `--cap-add=SYS_PTRACE` depending on your Docker version and kernel version. 
[The flag is not needed since Docker 19.03+ with kernel 4.8+](https://github.com/moby/moby/pull/38137).

## Example

`docker run -it --rm weberlars/diuid docker info`

For better performance, mount a tmpfs with exec access on `/umlshm`:

`docker run -it --rm --tmpfs /umlshm:rw,nosuid,nodev,exec,size=8g weberlars/diuid docker info`

To set `dockerd` flags:

`docker run it --rm -e DIUID_DOCKERD_FLAGS="--experimental --debug" weberlars/diuid docker info`

To configure memory size and `/var/lib/docker` size:
`docker run -it --rm -e MEM=4G -e DISK=20G weberlars/diuid docker info`

To preserve `/var/lib/docker` disk:
`docker run -it --rm -v /somewhere:/persistent weberlars/diuid docker info`

