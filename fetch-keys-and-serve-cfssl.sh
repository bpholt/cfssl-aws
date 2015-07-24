#!/bin/sh
aws s3 cp "$CA_CERT" /opt/dwolla/ca.pem
aws s3 cp "$CA_KEY" /opt/dwolla/ca-key.pem
aws s3 cp "$CFSSL_CONFIG" /opt/dwolla/config.json

exec cfssl \
        serve \
        -config /opt/dwolla/config.json \
        -ca /opt/dwolla/ca.pem \
        -ca-key /opt/dwolla/ca-key.pem \
        $@
