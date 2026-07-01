#!/bin/bash
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

ESO_NS="external-secrets"

set -x

kubectl -n external-secrets describe externalsecret conjur
sleep 1
echo "Decoded conjur-secret values:"
kubectl -n $ESO_NS get secret conjur-secret -o go-template='{{range $k,$v := .data}}{{$k}}: {{$v | base64decode}}
{{end}}'

set +x
