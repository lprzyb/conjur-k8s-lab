#!/bin/sh
openssl s_client -showcerts -servername conjur-leader.demo.local \
    -connect conjur-leader.demo.local:443 < /dev/null 2> /dev/null \
    | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > conjur.pem
