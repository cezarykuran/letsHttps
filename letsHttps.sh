#!/bin/bash

wd=$(dirname $0)
cd $wd

test ! -d 'acme-tiny-master' && {
    echo 'Downoading acme-tiny..'
    wget https://github.com/diafygi/acme-tiny/archive/master.zip
    unzip master.zip && rm master.zip
    echo
}

test ! -f 'account.key' && {
    echo 'Generating account.key..'
    openssl genrsa 4096 > account.key
    echo
}

test -z "$1" && {
    echo -e "Usage: `basename $0` domain [subdomain1] [subdomain2]\nExample: `basename $0` domain.com www forum www.forum" >&2
    exit
}


domain="$1"
domains=""
for subdomain in "${@:2}"; do
    domains="DNS:$subdomain,$domains"
done
test -n "$domains" && domains="DNS:$domain,$domains"



acmeDir=~/domains/$domain/public_html/.well-known/acme-challenge/
echo "Creating challenge dir $acmeDir (remove it manualy).."
mkdir -p $acmeDir

echo 'Generating private key..'
openssl genrsa 4096 > $domain.key

echo 'Generating certificate signing request..'
test -n "$domains" && {
    openssl req -new -sha256 -key $domain.key -subj "/" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=$domains")) > $domain.csr
} || {
    openssl req -new -sha256 -key $domain.key -subj "/CN=$domain" > $domain.csr
}
echo

echo 'Generating certificate request..'
python acme-tiny-master/acme_tiny.py --account-key account.key --csr $domain.csr --acme-dir $acmeDir > $domain.crt

