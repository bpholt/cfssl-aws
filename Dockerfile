FROM quay.io/jcjones/cfssl:latest
MAINTAINER Brian Holt bholt@dwolla.net

RUN apt-get update && \
    apt-get -y install python2.7 python-pip && \
    pip install awscli && \
    apt-get clean && \
    groupadd -r cfssl -g 433 && \
    useradd -u 431 -r -g cfssl -d /opt/dwolla -s /sbin/nologin -c "CFSSL daemon account" cfssl && \
    mkdir -p /opt/dwolla && \
    chown -R cfssl:cfssl /opt/dwolla
USER cfssl
WORKDIR /opt/dwolla
ADD fetch-keys-and-serve-cfssl.sh /opt/dwolla/fetch-keys-and-serve-cfssl.sh

ENTRYPOINT ["/opt/dwolla/fetch-keys-and-serve-cfssl.sh"]
