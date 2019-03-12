#!/bin/bash

set -e

pgname=$(basename $0)
wd=$(dirname $0)

sslDir='ssl'


help() {
    echo "Usage:"
    echo "$pgname -a pathToAcmeDir [-n name] -d domain.com [-d subdomain.domain.com] [-d anotherdomain.com]"
    echo
    echo "Example:"
    echo "$pgname -a /var/www/htdocs/domain.com/.well-known/acme-challenge/ -d domain.com -d www.domain.com"
    echo
    exit
}


acmeDir=''
name=''
domains=()

while getopts ":n:d:a:s:h" opt; do
    case $opt in
        a)
            acmeDir="$OPTARG"
            ;;
        n)
            name="$OPTARG"
            ;;
        d)
            domains+=("$OPTARG")
            test -z "$name" && name="$OPTARG"
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

e=''
test -z "$acmeDir" && e="$e -empty acme dir\n";
test -z "$name" && e="$e -empty cert/key name\n";
test ${#domains[@]} -eq 0 && e="$e -empty domain name\n";
test -n "$e" && {
    echo -e "$pgname error:\n$e\nTry -h for help.\n" >&2
    exit 1
}


echo
echo "acme dir : $acmeDir"
echo "name     : $name"
echo "domains  : ${domains[@]}"
echo

e=''
for domain in "${domains[@]}"; do test $($wd/getent hosts $domain | awk '{ print $1 }') != '127.0.0.1' && e="$e -$domain\n"; done
test -n "$e" && echo -e "Warning, not 127.0.0.1 domains:\n$e"

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
    openssl genrsa 4096 > "account.key"
    echo
}

test ! -d "$acmeDir" && {
    echo "Creating challenge dir '$acmeDir' (remove it manualy).."
    mkdir -p "$acmeDir"
}

echo 'Generating private key..'
openssl genrsa 4096 > "$sslDir/$name.key"

echo 'Generating certificate signing request..'
test ${#domains[@]} -gt 1 && {
    for domain in "${domains[@]}"; do SAN="$SAN,DNS:$domain"; done; SAN=${SAN:1}
    openssl req -new -sha256 -key "$sslDir/$name.key" -subj "/" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=$SAN")) > "$sslDir/$name.csr"
} || {
    CN="${domains[0]}"
    openssl req -new -sha256 -key "$sslDir/$name.key" -subj "/CN=$CN" > "$sslDir/$name.csr"
}
echo

echo 'Generating certificate request..'
python acme-tiny-master/acme_tiny.py --account-key account.key --csr "$sslDir/$name.csr" --acme-dir "$acmeDir" > "$sslDir/$name.crt"
echo

echo "Output files:"
ls "$sslDir/$name"*
echo

echo 'Bye!!'
