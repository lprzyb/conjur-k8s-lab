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
RC=$?

set +x
if [ $RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m conjur-secret synced by ESO and readable.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./05.running-cityapp-eso.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m conjur-secret not found/readable yet - ESO may still be syncing, check the output above.\n'
fi
