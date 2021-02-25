#!/bin/bash

if [ ! -f "variables.sh" ] ;
then
	echo "Can't find variables file variables.sh!"
	exit
fi

source variables.sh

openssl req -days $DAYS -x509 -nodes -newkey rsa:4096 -keyout "$RSA_KEY" -out "$RSA_CRT" -subj "/CN=sealed-secret/O=sealed-secret"