# Purpose of this Dockerfile is to create a VIC image that runs nested Docker that can be accessed remotely
# You can use this image to build Docker images, general development, run tests etc.

# See README for more details

FROM vmware/photon

ADD rc.local /etc/rc.local

RUN tdnf install -y procps-ng iptables net-tools openvswitch tar gzip
RUN chmod +x /etc/rc.local 
RUN curl -L'#' https://get.docker.com/builds/Linux/x86_64/docker-17.03.1-ce.tgz | tar --strip-components=1 -C /usr/bin -xzf -

EXPOSE 2375

CMD ["/etc/rc.local"]
