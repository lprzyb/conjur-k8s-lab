#!/bin/sh

#Change your configuration and set READY=true when done
READY=false

#IP addresses of Secrets Manager and crc VM
CONJUR_IP=172.16.100.15
LAB_IP=$CONJUR_IP
LAB_DOMAIN=demo.local
LAB_CONJUR_ADMIN_PW=ChangeMe123!
LAB_CONJUR_ACCOUNT=DEMO
#Secrets Manager leader hostname - used by 04,05,06,10.sh
CONJUR_LEADER_HOST=conjur-leader.$LAB_DOMAIN
#MySQL hostname - used by 02.running-mysql-db.sh (actual /etc/hosts entry) and 07.loading-demo-data.sh (value handed out via Secrets Manager, must match)
DB_HOST=mysql.$LAB_DOMAIN
#Path to folder with all docker images
UPLOAD_DIR=/opt/lab/setup_files
#Example only - confirm the exact filename/version against what you downloaded from Idira
conjur_appliance_file=conjur-appliance-Rls-v13.9.0.tar.gz
conjur_version=13.9.0
#Secrets Manager container name
node_name=conjur

#Demo MySQL credentials - used by 02.running-mysql-db.sh (actual DB) and 07.loading-demo-data.sh (value handed out via Secrets Manager, must match)
DB_ROOT_PASSWORD=Cyberark1
DB_USER=cityapp
DB_PASSWORD=Cyberark1

#JWT audience claim - used by 09.loading-conjur-jwt-data.sh (Secrets Manager side) and templated into follower/follower.yaml by 11.deploying-follower-k8s.sh (k8s side), must match
JWT_AUDIENCE=cybrdemo

