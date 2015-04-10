#!/bin/sh
#
# MxDynDNS is a DynDNS script allowing a user to dynamically update
# his IP on a CPanel Server
#
# Author: Adnan "Max13" RIHAN
#
# License: MIT

if [ "$1" = "--help" ] || [ "$#" -ne 4 ]; then
    echo "Usage: $(basename $0) <cpanel username> <cpanel password> <root-domain> <sub-domain>\n" >&2
    echo "Example: $(basename $0) mydomain ******** example.com home\n" >&2
    exit 1
fi

URL_IPECHO="http://api.v-info.info/ipecho"
URL_FETCHZONE="https://cpanel.virtual-info.info/json-api/cpanel?cpanel_jsonapi_apiversion=2&cpanel_jsonapi_module=ZoneEdit&cpanel_jsonapi_func=fetchzone&domain=$3&customonly=1&type=A&name=$4.$3."
URL_REMOVEZONE="https://cpanel.virtual-info.info/json-api/cpanel?cpanel_jsonapi_apiversion=2&cpanel_jsonapi_module=ZoneEdit&cpanel_jsonapi_func=remove_zone_record&domain=$3&line="
URL_ADDZONE="https://cpanel.virtual-info.info/json-api/cpanel?cpanel_jsonapi_apiversion=2&cpanel_jsonapi_module=ZoneEdit&cpanel_jsonapi_func=add_zone_record&domain=$3&name=$4&type=A&&ttl=1800&address="

HTTPCMD=
HTTPOPT=
HTTPAUTH="--basic -u $1:$2"
IP=
ZONES_LINES=""

if hash curl 2>&1; then
    HTTPCMD=curl
    HTTPOPT="--compressed -f -s"
elif hash wget 2>&1; then
    HTTPCMD=wget
    HTTPOPT="-O- -q --no-check-certificate"
    HTTPAUTH="--http-user=$1 --http-password=$2"
else
    echo "This script needs curl or wget to work properly... Exiting." >&2
    exit 1
fi

get_ip () {
    IP=`$HTTPCMD $HTTPOPT $URL_IPECHO`
    [ "$?" -eq 0 ] && return 0 || return 1
}

fetch_zone () {
    ZONES_LINES=`$HTTPCMD $HTTPOPT $HTTPAUTH $URL_FETCHZONE | grep -o "\"line\":[0-9]\+" | cut -c 8-`

    [ "$?" -eq 0 ] && return 0 || return 1
}

remove_zones () {
    for line in $ZONES_LINES; do
        if ! $HTTPCMD $HTTPOPT $HTTPAUTH $URL_REMOVEZONE$line > /dev/null 2>&1; then
            return 1
        fi
    done

    return 0
}

add_zone () {
    if ! $HTTPCMD $HTTPOPT $HTTPAUTH $URL_ADDZONE$IP > /dev/null 2>&1; then
        return 1
    fi

    return 0
}

if get_ip; then
    echo "Your public IP is: $IP"
else
    echo "Can't retrieve public IP. Connect your computer you fool !" >&2
    exit 1
fi

# -----

if fetch_zone; then
    if [ -n "$ZONES_LINES" ]; then
        echo "We need to remove existing zones: \c"
        if remove_zones; then
            echo "OK"
        else
            echo "KO"
            exit 1
        fi
    fi
else
    echo "Can't fetch your account zones. Maybe your credentials aren't correct !" >&2
    exit 1
fi

echo "Adding updated zone: $4.$3 => $IP"
if add_zone; then
    echo "OK"
else
    echo "KO"
    exit 1
fi
