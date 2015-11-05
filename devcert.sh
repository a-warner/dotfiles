openssl req -newkey rsa:2048 -sha512 -nodes -keyout powdev.key -x509 -days 365 -out powdev.crt
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain powdev.crt

mkdir -p /usr/local/etc/nginx/ssl
cp powdev.key /usr/local/etc/nginx/ssl
cp powdev.crt /usr/local/etc/nginx/ssl

cp pow_nginx_config /usr/local/etc/nginx/servers/powdev.dev

