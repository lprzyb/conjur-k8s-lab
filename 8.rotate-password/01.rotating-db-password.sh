#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

MODE="${1:-shared}"

case "$MODE" in
    shared|eso|all) ;;
    *)
        echo "Usage: $0 [shared|eso|all]"
        echo "  shared (default): rotate the real MySQL password and update test/CityApp/DBAccount/password only - test/CityAppESO/DBAccountESO/password (cityapp-eso) is intentionally left stale, demonstrating what rotation costs an app pointed at the wrong variable."
        echo "  eso: sync test/CityAppESO/DBAccountESO/password to test/CityApp/DBAccount/password's CURRENT value - no new password, no MySQL change. Use this to repair cityapp-eso after a shared rotation, without doing a fresh rotation."
        echo "  all: rotate the real MySQL password and update both test/CityApp/DBAccount/password and test/CityAppESO/DBAccountESO/password together - every Secrets Manager-integrated variant keeps working."
        exit 1
        ;;
esac

# Default (MODE=shared) deliberately only updates test/CityApp/DBAccount/password, not
# test/CityAppESO/DBAccountESO/password - this is the demo story: cityapp-conjurtok8sfile,
# cityapp-conjurtok8ssecret, cityapp-conjurtok8ssecret-init,
# cityapp-springboot-sidecar, cityapp-springboot-native, cityapp-csi and
# cityapp-summon all read test/CityApp/DBAccount/* and keep working (live, or after a
# redeploy - see README.md PART IV for exactly which apps need which).
# cityapp-eso reads the separate test/CityAppESO/DBAccountESO/* copy (see
# 5.conjur-eso/02.adding-conjur-eso-policy.sh) and is intentionally left
# behind here, right alongside cityapp-hardcode which never talks to
# Secrets Manager at all - both go stale, everything else survives the rotation.
# Pass "eso" to repair just cityapp-eso afterward without a fresh
# rotation, or "all" to rotate both together from the start.

# The full "watch it rotate" story only makes sense once all 9 demo
# variants are actually deployed - warn and confirm if some are missing,
# rather than silently rotating against a partial lab.
DEMO_DEPLOYMENTS="cityapp:cityapp-hardcode cityapp:cityapp-conjurtok8sfile cityapp:cityapp-conjurtok8ssecret cityapp:cityapp-conjurtok8ssecret-init cityapp:cityapp-springboot-sidecar cityapp:cityapp-springboot-native external-secrets:cityapp-eso cityapp:cityapp-csi cityapp:cityapp-summon"
FOUND_COUNT=0
MISSING=""
for entry in $DEMO_DEPLOYMENTS; do
    ns=${entry%%:*}
    name=${entry#*:}
    if kubectl -n $ns get deployment $name >/dev/null 2>&1; then
        FOUND_COUNT=$((FOUND_COUNT + 1))
    else
        MISSING="$MISSING $name"
    fi
done

if [ $FOUND_COUNT -lt 9 ]; then
    printf '\033[1;33m⚠️  Warning:\033[0m only %s/9 cityapp demo deployments found. Missing:%s\n' "$FOUND_COUNT" "$MISSING"
    printf 'Rotating now means those missing variants will not be part of the "watch it rotate" comparison until you deploy them. Rotate anyway? [y/N] '
    read CONFIRM
    case "$CONFIRM" in
        y|Y|yes|YES) ;;
        *) echo "Aborted - no changes made."; exit 0 ;;
    esac
fi

if [ "$MODE" = "eso" ]; then
    set -x
    CURRENT_PASSWORD=$(conjur variable get -i test/CityApp/DBAccount/password)
    GET_RC=$?

    conjur variable set -i test/CityAppESO/DBAccountESO/password -v "$CURRENT_PASSWORD"
    ESO_RC=$?
    set +x

    if [ $GET_RC -eq 0 ] && [ $ESO_RC -eq 0 ]; then
        printf '\033[1;32m✅ Done:\033[0m test/CityAppESO/DBAccountESO/password synced to test/CityApp/DBAccount/password'"'"'s current value.\n'
        printf '\033[1;33m➡️  Next:\033[0m cityapp-eso will pick this up on its own sync schedule - no MySQL change was needed since the password itself did not change.\n'
    else
        printf '\033[1;31m❌ Failed:\033[0m could not read test/CityApp/DBAccount/password or update test/CityAppESO/DBAccountESO/password - check the output above.\n'
    fi
    exit
fi

NEW_PASSWORD=$(openssl rand -base64 18 | tr -d '=+/')

set -x
podman exec mysqldb mysql -uroot -p$DB_ROOT_PASSWORD -e "ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$NEW_PASSWORD'; FLUSH PRIVILEGES;"
MYSQL_RC=$?

conjur variable set -i test/CityApp/DBAccount/password -v "$NEW_PASSWORD"
SHARED_RC=$?

ESO_RC=0
if [ "$MODE" = "all" ]; then
    conjur variable set -i test/CityAppESO/DBAccountESO/password -v "$NEW_PASSWORD"
    ESO_RC=$?
fi
set +x

if [ $MYSQL_RC -eq 0 ] && [ $SHARED_RC -eq 0 ] && [ $ESO_RC -eq 0 ]; then
    if [ "$MODE" = "all" ]; then
        printf '\033[1;32m✅ Done:\033[0m %s password rotated in MySQL and updated in Secrets Manager (test/CityApp/DBAccount/password and test/CityAppESO/DBAccountESO/password).\n' "$DB_USER"
        printf '\033[1;33m➡️  Next:\033[0m cityapp-conjurtok8sfile and cityapp-conjurtok8ssecret refresh live within their secrets-refresh-interval, no redeploy needed. cityapp-conjurtok8ssecret-init (fetches once via a true initContainer at pod creation, no ongoing refresh process), cityapp-springboot-sidecar (secret wired up as an env var, frozen at pod start), cityapp-springboot-native (fetches once via the Secrets Manager SDK at startup), cityapp-csi (rotation is not enabled on this lab'"'"'s CSI driver install) and cityapp-summon (Summon fetches once and exec'"'"'s into cityapp'"'"'s process, no refresh loop of its own) all need a redeploy to pick it up. cityapp-hardcode is the only one still stuck on the old password now, since it never talks to Secrets Manager at all.\n'
    else
        printf '\033[1;32m✅ Done:\033[0m %s password rotated in MySQL and updated in Secrets Manager (test/CityApp/DBAccount/password only - test/CityAppESO/DBAccountESO/password left untouched on purpose).\n' "$DB_USER"
        printf '\033[1;33m➡️  Next:\033[0m cityapp-conjurtok8sfile and cityapp-conjurtok8ssecret refresh live within their secrets-refresh-interval, no redeploy needed. cityapp-conjurtok8ssecret-init, cityapp-springboot-sidecar, cityapp-springboot-native, cityapp-csi and cityapp-summon need a redeploy to pick it up. cityapp-hardcode and cityapp-eso are now both stuck on the old password: hardcode because it never talks to Secrets Manager at all, eso because it reads test/CityAppESO/DBAccountESO/* which this script left alone by default - run this script again with "eso" to repair just that, or "all" next time to rotate both together from the start.\n'
    fi
else
    printf '\033[1;31m❌ Failed:\033[0m password rotation failed partway through - check the output above. MySQL and Secrets Manager may now be out of sync; do not leave it in this state, re-run once you have fixed the cause.\n'
fi
