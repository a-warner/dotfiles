#!/usr/bin/env sh
set -e

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 DOMAIN_NAME"
  exit 1
fi

sed "s/SERVER_NAME_FIELD/$DOMAIN/" openssl.cnf.template > ${DOMAIN}-openssl.cnf

openssl req -newkey rsa:2048 -sha512 -nodes -keyout $DOMAIN.key -x509 -days 365 -out $DOMAIN.crt -subj "/CN=$DOMAIN" -config ${DOMAIN}-openssl.cnf
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $DOMAIN.crt

mkdir -p /usr/local/etc/nginx/ssl
cp $DOMAIN.key /usr/local/etc/nginx/ssl
cp $DOMAIN.crt /usr/local/etc/nginx/ssl

sed "s/SERVER_NAME_FIELD/$DOMAIN/" pow_nginx_config > /usr/local/etc/nginx/servers/$DOMAIN.dev

sudo nginx -s quit
sudo nginx
