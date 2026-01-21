#!/bin/bash

set -e

printf '\nset user agent\n\n'

FILE_RELAY=Sources/WalletConnectRelay/PackageConfig.json
FILE_PAY=Sources/WalletConnectPay/PackageConfig.json

if [ -f "$FILE_RELAY" ];
then
    printf '\ncurrent user agent (Relay):\n'
    cat "$FILE_RELAY"
    printf '\nsetting user agent... \n'
    echo "{\"version\": \"$PACKAGE_VERSION\"}" > "$FILE_RELAY"
    printf '\nuser agent set for (Relay):\n'
    cat "$FILE_RELAY"
else
    printf '\nError setting PACKAGE_VERSION for Relay\n\n'
fi

if [ -f "$FILE_PAY" ];
then
    printf '\ncurrent user agent (Pay):\n'
    cat "$FILE_PAY"
    printf '\nsetting user agent... \n'
    echo "{\"version\": \"$PACKAGE_VERSION\"}" > "$FILE_PAY"
    printf '\nuser agent set for (Pay):\n'
    cat "$FILE_PAY"
else
    printf '\nError setting PACKAGE_VERSION for Pay\n\n'
fi

