FROM debian:latest

MAINTAINER weber@weber-software.com

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

ADD linux /linux/linux
ADD entrypoint.sh entrypoint.sh
ADD init.sh init.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "bash" ]