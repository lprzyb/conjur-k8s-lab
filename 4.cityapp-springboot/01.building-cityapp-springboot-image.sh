#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

FALLBACK_IMAGE="docker.io/huydd79/cityapp-springboot:latest"

set -x

#Downloading necessary packages for app building
sudo dnf install -y java-17-openjdk java-17-openjdk-devel

cd build
if sudo bash -c "./mvnw clean package" && sudo podman build -t cityapp-springboot .; then
    echo "Built cityapp-springboot locally"
else
    echo "Local build failed - falling back to prebuilt image $FALLBACK_IMAGE"
    sudo podman pull $FALLBACK_IMAGE
    sudo podman tag $FALLBACK_IMAGE cityapp-springboot
fi
cd ..
sudo podman image ls | grep cityapp-springboot

set +x
