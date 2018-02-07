MAINTAINER weber@weber-software.com

FROM debian:latest as kernel_build

RUN apt-get update 
RUN apt-get install git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc -y
RUN apt-get install -y --no-install-recommends bsdtar

ADD https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.8.2.tar.xz .

RUN export tar='bsdtar'
RUN tar vxf linux-4.8.2.tar.xz

WORKDIR linux-4.8.2
COPY KERNEL.config .config
RUN make V=1 ARCH=um


FROM debian:latest

#used to connect to the dockerd inside the uml kernel
ENV DOCKER_HOST tcp://127.0.0.1:2375

RUN \
	apt-get update && \
	apt-get install -y wget slirp net-tools cgroupfs-mount openssh-server psmisc

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

COPY --from=kernel_build linux-4.8.2/linux /linux/linux
ADD entrypoint.sh entrypoint.sh
ADD init.sh init.sh

#specify the of memory that the uml kernel can use 
ENV MEM 2G

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "bash" ]
