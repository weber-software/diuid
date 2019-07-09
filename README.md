# Docker in User Mode Linux

An image for running a dockerd inside a user mode linux kernel.
This way it is possible to run and build docker images without forwarding the docker socket or using privileged flags.
Therefore this image can be used to build docker images with the gitlab-ci-multi-runner docker executor.

## How it works

It starts a user mode linux kernel with a dockerd inside.
The network communication is bridged by slirp.
I didn't managed to get the "redir" of slirp to work and so i'm forwarding the docker socket using TCP reverse tunneling over an SSH connection from the uml kernel to the container.

## Security

Because uml linux is using ptrace the image might need to be started with `--cap-add=SYS_PTRACE` depending on your Docker version and kernel version. 
[The flag is not needed since Docker 19.03+ with kernel 4.8+](https://github.com/moby/moby/pull/38137).

## Example

Uml linux requires a tmpfs with exec access:

`docker run -it --rm -e TMPDIR=/umlshm --tmpfs /umlshm:rw,nosuid,nodev,exec,size=8g weberlars/diuid docker info`
