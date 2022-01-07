ARG DEBIAN_VERSION=11.2
ARG KERNEL_VERSION=5.15
ARG GOLANG_VERSION=1.17.6
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=5:20.10.12~3-0~debian-bullseye
ARG SLIRP4NETNS_VERSION=1.2.0-beta.0

FROM debian:$DEBIAN_VERSION as kernel_build

RUN \
	apt-get update && \
	apt-get install git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc wget flex bison libelf-dev -y && \
	apt-get install -y --no-install-recommends libarchive-tools

ARG KERNEL_VERSION

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
FROM debian:$DEBIAN_VERSION AS print_config
COPY --from=kernel_build /KERNEL.config /KERNEL.CONFIG
CMD ["cat", "/KERNEL.CONFIG"]

FROM golang:$GOLANG_VERSION AS diuid-docker-proxy
COPY diuid-docker-proxy /go/src/github.com/weber-software/diuid/diuid-docker-proxy
WORKDIR /go/src/github.com/weber-software/diuid/diuid-docker-proxy
RUN go build -o /diuid-docker-proxy

FROM debian:$DEBIAN_VERSION

LABEL maintainer="weber@weber-software.com"

RUN \
	apt-get update && \
	apt-get install -y wget net-tools openssh-server psmisc rng-tools \
	apt-transport-https ca-certificates gnupg2 software-properties-common iptables iproute2

RUN \
	update-alternatives --set iptables /usr/sbin/iptables-legacy && \
	update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

RUN \
	mkdir /root/.ssh && \
	ssh-keygen -b 2048 -t rsa -f /root/.ssh/id_rsa -q -N "" && \
	cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

#install docker
ARG DOCKER_CHANNEL
ARG DOCKER_VERSION
RUN \
    wget -O - https://download.docker.com/linux/debian/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) $DOCKER_CHANNEL" && \
    apt-get update && \
    apt-cache madison docker-ce && \
    apt-get install -y docker-ce=$DOCKER_VERSION docker-ce-cli=$DOCKER_VERSION containerd.io

#install diuid-docker-proxy
COPY --from=diuid-docker-proxy /diuid-docker-proxy /usr/bin
RUN echo GatewayPorts=yes >> /etc/ssh/sshd_config

#install slirp4netns (used by UML)
ARG SLIRP4NETNS_VERSION
RUN \
  wget -O /usr/bin/slirp4netns https://github.com/rootless-containers/slirp4netns/releases/download/v${SLIRP4NETNS_VERSION}/slirp4netns-x86_64 && \
  chmod +x /usr/bin/slirp4netns

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
