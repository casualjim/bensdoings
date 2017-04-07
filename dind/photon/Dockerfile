# Purpose of this Dockerfile is to create a VIC image that runs nested Docker that can be accessed remotely
# You can use this image to build Docker images, general development, run tests etc.

# See README for more details

FROM vmware/photon


RUN tdnf install --refresh -y procps-ng iptables net-tools openvswitch tar gzip openssh sed
RUN curl -L'#' https://get.docker.com/builds/Linux/x86_64/docker-17.03.1-ce.tgz | tar --strip-components=1 -C /usr/bin -xzf -
RUN sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config


EXPOSE 2375

CMD ["/etc/rc.local"]

RUN echo 'root:Admin!23' | chpasswd
# added last to promote reuse while editing rc.local
ADD rc.local /etc/rc.local
RUN chmod +x /etc/rc.local
