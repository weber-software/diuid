FROM debian:9.9 as kernel_build
ARG KERNEL_VERSION=5.2

RUN \
	apt-get update && \
	apt-get install git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc wget flex bison libelf-dev -y && \
	apt-get install -y --no-install-recommends bsdtar

RUN \
	wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz && \
	tar -xf linux-$KERNEL_VERSION.tar.xz && \
	rm linux-$KERNEL_VERSION.tar.xz

WORKDIR linux-$KERNEL_VERSION
COPY KERNEL.config .config
RUN make ARCH=um oldconfig && make ARCH=um prepare
RUN make ARCH=um -j `nproc`
RUN mkdir /out && cp -f linux /out/linux

RUN cp .config /KERNEL.config

# usage: docker build -t foo --target print_config . && docker run -it --rm foo > KERNEL.config
FROM debian:9.9 AS print_config
COPY --from=kernel_build /KERNEL.config /KERNEL.CONFIG
CMD ["cat", "/KERNEL.CONFIG"]

FROM golang:1.12 AS diuid-docker-proxy
COPY diuid-docker-proxy /go/src/github.com/weber-software/diuid/diuid-docker-proxy
RUN go build -o /diuid-docker-proxy /go/src/github.com/weber-software/diuid/diuid-docker-proxy

FROM debian:9.9

LABEL maintainer="weber@weber-software.com"

RUN \
	apt-get update && \
	apt-get install -y wget slirp net-tools cgroupfs-mount openssh-server psmisc rng-tools

RUN \
	mkdir /root/.ssh && \
	ssh-keygen -b 2048 -t rsa -f /root/.ssh/id_rsa -q -N "" && \
	cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

#install docker
RUN \
	wget https://get.docker.com/ -O ./get_docker_com.sh && \
	chmod +x ./get_docker_com.sh && \
	./get_docker_com.sh && \
	rm -rf ./get_docker_com.sh

#install diuid-docker-proxy
COPY --from=diuid-docker-proxy /diuid-docker-proxy /usr/bin
RUN echo GatewayPorts=yes >> /etc/ssh/sshd_config

#install kernel and scripts
COPY --from=kernel_build /out/linux /linux/linux
ADD kernel.sh kernel.sh
ADD entrypoint.sh entrypoint.sh
ADD init.sh init.sh

#specify the of memory that the uml kernel can use 
ENV MEM 2G
ENV TMPDIR /umlshm

#it is recommended to override /umlshm with
#--tmpfs /umlshm:rw,nosuid,nodev,exec,size=8g
VOLUME /umlshm

ENV DISK 10G

#disk image for /var/lib/docker is created under this directory
VOLUME /persistent

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "bash" ]
