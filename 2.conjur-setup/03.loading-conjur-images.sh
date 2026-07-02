#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
# Loading conjur appliance image
podman image ls | grep -q conjur-appliance && echo "Image conjur-appliance existed!!!" || podman load -i $UPLOAD_DIR/$conjur_appliance_file
set +x
printf '\033[1;32m✅ Done:\033[0m Conjur appliance image loaded.\n'
printf '\033[1;33m➡️  Next:\033[0m run ./04.starting-conjur-container.sh\n'
