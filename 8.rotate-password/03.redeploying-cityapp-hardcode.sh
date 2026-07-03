#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

# cityapp-hardcode never talks to Secrets Manager at all - its DB password
# is a literal string baked into its Deployment spec (DBPASS env value in
# 3.cityapp-setup/yaml/cityapp-hardcode.yaml). Every other variant in this
# lab either updates live or just needs a redeploy to fetch a fresh value;
# this one has no secret to fetch - the only "fix" is to manually edit the
# hardcoded string and redeploy, which is exactly what this script does,
# on purpose, so that manual step is visible rather than hidden.

APP_NAME="cityapp-hardcode"
YML_FILE="../3.cityapp-setup/yaml/$APP_NAME.yaml"
YML_TEMP="/tmp/$APP_NAME.yaml"

CURRENT_PASSWORD=$(conjur variable get -i test/CityApp/DBAccount/password)
if [ -z "$CURRENT_PASSWORD" ]; then
    printf '\033[1;31m❌ Failed:\033[0m could not read test/CityApp/DBAccount/password from Secrets Manager - check the output above.\n'
    exit 1
fi

OLD_DBPASS=$(kubectl -n cityapp get deployment $APP_NAME -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DBPASS")].value}' 2>/dev/null)
[ -z "$OLD_DBPASS" ] && OLD_DBPASS="(no cityapp-hardcode deployment currently running)"

printf '\033[1;36mℹ️  cityapp-hardcode has no secret to rotate - its password is a literal string in the spec. Replacing it by hand:\033[0m\n'
echo
echo "  --- current spec ---"
echo "          - name: DBPASS"
echo "            value: '$OLD_DBPASS'"
echo
echo "  --- new spec ---"
echo "          - name: DBPASS"
echo "            value: '$CURRENT_PASSWORD'"
echo

set -x
kubectl get namespace | grep -q cityapp || kubectl create namespace cityapp
kubectl -n cityapp get deployment $APP_NAME >/dev/null 2>&1
if [ $? -eq 0 ]; then
    kubectl -n cityapp delete deployment $APP_NAME
    ret=0
    until [ $ret -ne 0 ]
    do
        kubectl -n cityapp get deployment $APP_NAME >/dev/null 2>&1
        ret=$?
        echo "Waiting deployment is deleted..."
        sleep 1
    done
fi

cp $YML_FILE $YML_TEMP
sed -i "s/{LAB_IP}/$LAB_IP/g" $YML_TEMP
sed -i "s/{LAB_DOMAIN}/$LAB_DOMAIN/g" $YML_TEMP
sed -i "s/{DB_HOST}/$DB_HOST/g" $YML_TEMP
sed -i "s/{DB_USER}/$DB_USER/g" $YML_TEMP
sed -i "s/{DB_PASSWORD}/$CURRENT_PASSWORD/g" $YML_TEMP

kubectl -n cityapp apply -f $YML_TEMP
RC=$?

rm $YML_TEMP
set +x

if [ $RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m cityapp-hardcode redeployed with the current real MySQL password hardcoded into its spec.\n'
    printf '\033[1;33m➡️  Next:\033[0m this only holds until the next rotation - since cityapp-hardcode never reads from Secrets Manager, this manual edit-and-redeploy is the only way to keep it working, unlike every other variant in this lab.\n'
else
    printf '\033[1;31m❌ Failed:\033[0m redeploy failed - check the output above.\n'
fi
