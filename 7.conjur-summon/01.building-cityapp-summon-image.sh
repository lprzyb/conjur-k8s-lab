#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

# Builds localhost/cityapp:summon on top of localhost/cityapp:php - requires
# 3.cityapp-setup/01.building-cityapp-image.sh to have been run first. Adds
# the Summon binary and the summon-conjur provider, and overrides the
# entrypoint to wrap apache2-foreground with summon so the fetched secrets
# land as real process env vars before cityapp ever starts.
set -x

cd build
podman build -t cityapp:summon .
cd ..
podman image ls | grep cityapp
set +x
