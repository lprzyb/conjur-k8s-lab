#!/bin/sh
source ../2.conjur-setup/00.config.sh
#Change your configuration and set READY=true when done
READY=false

#JWT audience the CSI driver requests tokens with (set via 00.installing-csi-helm.sh)
#and that conjur/authn-jwt/k8s-csi/audience must match - see 01.adding-conjur-csi-jwt-policy.sh
CSI_JWT_AUDIENCE=conjur
