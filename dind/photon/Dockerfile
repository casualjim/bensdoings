# Purpose of this Dockerfile is to create a VIC image that runs nested Docker that can be accessed remotely
# You can use this image to build Docker images, general development, run tests etc.

# See README for more details

FROM vmware/photon

ARG TINI_VERSION=v0.14.0

ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
ADD rc.local /etc/rc.local

RUN tdnf install -y procps-ng iptables net-tools openvswitch tar gzip
RUN chmod +x /usr/bin/tini /etc/rc.local && curl -L'#' https://get.docker.com/builds/Linux/x86_64/docker-17.03.1-ce.tgz | tar --strip-components=1 -C /usr/bin -xzf -

EXPOSE 2376

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/etc/rc.local"]
