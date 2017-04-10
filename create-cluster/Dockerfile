FROM casualjim/vic-machine-base:nsx

RUN apt-get install -y libltdl-dev ssh-client sshpass netcat

ENV TERM xterm-256color

COPY docker govc *.sh /bin/

CMD /bin/create-ddc-nodes.sh /vic/vic-machine-linux /bin/create-ddc-cluster.sh
