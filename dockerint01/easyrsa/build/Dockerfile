FROM alpine:3.16

ENV VERSION=3.1.7
ENV EASYRSA_PKI=/easyrsa/pki

RUN apk upgrade --update && apk add openssl

RUN wget -O- https://github.com/OpenVPN/easy-rsa/releases/download/v${VERSION}/EasyRSA-${VERSION}.tgz | tar -C / -zx && mv EasyRSA-${VERSION}/* /usr/local/bin && chown -R root:root /usr/local/bin

ADD vars /usr/local/bin/vars