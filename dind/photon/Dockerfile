# Purpose of this Dockerfile is to create a VIC image that runs nested Docker that can be accessed remotely
# You can use this image to build Docker images, general development, run tests etc.

# See README for more details

FROM vmware/photon

COPY adduserkey /usr/bin
RUN tdnf install --refresh -y procps-ng iptables net-tools openvswitch tar gzip openssh sed iproute2 && tdnf clean
RUN curl -L'#' https://get.docker.com/builds/Linux/x86_64/docker-17.04.0-ce.tgz | tar --strip-components=1 -C /usr/bin -xzf -
RUN mkdir /var/run/sshd && chmod 700 /var/run/sshd \
    && chown root:root /usr/bin/adduserkey \
# Comment out next 3 lines if you do not want to bake in a particular non-root user/pwd combo
    && useradd -s /bin/bash -m -p $(openssl passwd -1 vmware) vmware \
    && su vmware && mkdir ~/.ssh && chmod 700 ~/.ssh \
    && echo "vmware   ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers.d/vmware \
    && usermod -aG docker vmware \    
    && sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config


CMD ["/etc/rc.local"]

RUN echo 'root:Admin!23' | chpasswd
# added last to promote reuse while editing rc.local
ADD rc.local /etc/rc.local
RUN chmod +x /etc/rc.local
