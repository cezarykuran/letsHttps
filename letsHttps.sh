#!/bin/bash

set -e

pgname=$(basename $0)
wd=$(dirname $0)
sslDir='ssl'

help() {
    echo "Usage:"
    echo "$pgname -d domain -a pathToAcmeDir [-s subdomain1] [-s subdomain2]"
    echo
    echo "Example:"
    echo "$pgname -d domain.com -p /var/www/htdocs/domain.com/.well-known/acme-challenge/ -s www -s forum -s www.forum"
    echo
    exit
}


echo '  _       _    _____  _    _'
echo ' | | ___ | |_ |  |  || |_ | |_  ___  ___ '
echo ' | || -_||  _||     ||  _||  _|| . ||_ -|'
echo ' |_||___||_|  |__|__||_|  |_|  |  _||___|'
echo '                          |_|'
echo


domain=''
acmeDir=''
subdomains=()

while getopts ":d:a:s:h" opt; do
    case $opt in
        d)
            domain="$OPTARG"
            ;;
        s)
            subdomains+=("$OPTARG")
            ;;
        a)
            acmeDir="$OPTARG"
            ;;
        h)
            help
            exit 0
            ;;
        \?)
            echo -e "Unknown -$OPTARG.\nTry -h for help.\n" >&2
            exit 1
            ;;
        :)
            echo -e "-$OPTARG require value.\nTry -h for help.\n" >&2
            exit 1
            ;;
    esac
done

test -z "$domain" && {
    echo -e "$pgname error: empty domain name.\nTry -h for help.\n" >&2
    exit 1
}

test -z "$acmeDir" && {
    echo -e "$pgname error: empty acme dir.\nTry -h for help.\n" >&2
    exit 1
}

echo    "domain     : $domain"
echo -n "subdomains : "; test ${#subdomains[@]} -gt 0 && echo "${subdomains[@]}" || echo '-'
echo    "acme dir   : $acmeDir"
echo
read -p "continue [y/n]? " -n1 yn
echo
test "$yn" == 'y' || exit 0


cd $wd

mkdir -p $sslDir
chmod 700 "$sslDir"

test ! -d 'acme-tiny-master' && {
    echo 'Downoading acme-tiny..'
    wget https://github.com/diafygi/acme-tiny/archive/master.zip
    unzip master.zip && rm master.zip
    echo
}

test ! -f 'account.key' && {
    echo 'Generating account.key..'
    openssl genrsa 4096 > "$sslDir/account.key"
    echo
}

domains=""
test ${#subdomains[@]} -gt 0 && {
    for subdomain in "${subdomains[@]}"; do
        domains="$domains,DNS:$subdomain.$domain"
    done
    domains="DNS:$domain$domains"
}

test ! -d "$acmeDir" && {
    echo "Creating challenge dir '$acmeDir' (remove it manualy).."
    mkdir -p "$acmeDir"
}

echo 'Generating private key..'
openssl genrsa 4096 > "$sslDir/$domain.key"

echo 'Generating certificate signing request..'
test -n "$domains" && {
    openssl req -new -sha256 -key "$sslDir/$domain.key" -subj "/" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=$domains")) > "$sslDir/$domain.csr"
} || {
    openssl req -new -sha256 -key "$sslDir/$domain.key" -subj "/CN=$domain" > "$sslDir/$domain.csr"
}
echo

echo 'Generating certificate request..'
python acme-tiny-master/acme_tiny.py --account-key account.key --csr "$sslDir/$domain.csr" --acme-dir "$acmeDir" > "$sslDir/$domain.crt"

echo
echo "Output files in '$sslDir':"
ls "$sslDir" | grep "$domain"

echo
echo 'Bye!!'
