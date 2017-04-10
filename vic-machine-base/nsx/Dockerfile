FROM debian:jessie

ARG DEBIAN_FRONTEND=noninteractive 
RUN apt-get update && apt-get install -y jq ca-certificates curl tar

CMD ["/bin/bash"]

ADD vic/appliance.iso /vic/
ADD vic/vic-machine-linux /vic/
ADD vic/bootstrap.iso /vic/
