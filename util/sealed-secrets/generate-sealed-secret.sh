#!/bin/bash

if [ ! -f "variables.sh" ] ;
then
	echo "Can't find variables file variables.sh!"
	exit
fi

if [ "$#" -ne 2 ] ;
then
	echo -e "Usage:\n$0 <scope> <secret yaml file>"
	exit
fi

case $1 in
	strict)
		;;
	namespace-wide)
		;;
	cluster-wide)
		;;
	*)
		echo "<scope> must be set to strict, namespace-wide or cluster-wide!"
		exit
		;;
esac

if [ ! -f "$2" ] ;
then
	echo "Could not find the file $2!"
	exit
fi

# shellcheck disable=SC1091
source variables.sh

kubeseal -o yaml --cert "${RSA_CRT}" --scope "$1" < "$2"