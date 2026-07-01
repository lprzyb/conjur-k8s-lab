#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

#db_dir=/var/run/mysql/db
db_dir=$(pwd)/mysql/db
set -x
mkdir -p $db_dir 
cp ./mysql/world.sql.gz $db_dir
gunzip $db_dir/world.sql.gz

podman stop mysqldb
podman rm mysqldb
podman run --name mysqldb -v $db_dir:/docker-entrypoint-initdb.d \
     -d --restart=always \
     -e MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWORD \
     -e MYSQL_DATABASE=world \
     -e MYSQL_USER=$DB_USER \
     -e MYSQL_PASSWORD=$DB_PASSWORD \
     -p "3306:3306" -d docker.io/library/mysql:8.4

grep -q "$DB_HOST" /etc/hosts || echo "$CONJUR_IP $DB_HOST" >> /etc/hosts
set +x

