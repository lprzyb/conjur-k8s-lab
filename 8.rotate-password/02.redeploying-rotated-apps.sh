#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

# Redeploys the 5 cityapp variants that do NOT pick up a rotated
# test/CityApp/DBAccount/password live (see README.md PART IV and CLAUDE.md for why each
# one needs this): cityapp-conjurtok8ssecret-init, cityapp-springboot-sidecar,
# cityapp-springboot-native, cityapp-csi and cityapp-summon. Each one is
# owned by a different folder, and each of those folders' own running
# script uses relative paths (source 00.config.sh, yaml/...) that only
# work with that folder as the current directory - so every step below
# runs in a subshell that cd's into the right folder first and resets
# back here automatically afterward.
#
# cityapp-conjurtok8sfile and cityapp-conjurtok8ssecret are deliberately
# NOT included here - they pick up a rotated password live and never
# need a redeploy. cityapp-hardcode and cityapp-eso are also excluded -
# neither one is fixed by a redeploy (see 01.rotating-db-password.sh's
# shared/eso/all modes for those instead).

set -x

( cd ../3.cityapp-setup && ./05.running-cityapp-conjurtok8ssecret-init.sh )
RC1=$?

( cd ../4.cityapp-springboot && ./02.running-cityapp-springboot-sidecar.sh )
RC2=$?

( cd ../4.cityapp-springboot && ./03.running-cityapp-springboot-native.sh )
RC3=$?

( cd ../6.conjur-csi && ./06.running-cityapp-csi-test.sh )
RC4=$?

( cd ../7.conjur-summon && ./03.running-cityapp-summon.sh )
RC5=$?

set +x

if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ] && [ $RC3 -eq 0 ] && [ $RC4 -eq 0 ] && [ $RC5 -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m cityapp-conjurtok8ssecret-init, cityapp-springboot-sidecar, cityapp-springboot-native, cityapp-csi and cityapp-summon all redeployed - each fetched the current test/CityApp/DBAccount/password fresh on startup.\n'
else
    printf '\033[1;31m❌ Failed:\033[0m at least one redeploy failed - check the output above for which one (RC1=%s conjurtok8ssecret-init, RC2=%s springboot-sidecar, RC3=%s springboot-native, RC4=%s csi, RC5=%s summon).\n' "$RC1" "$RC2" "$RC3" "$RC4" "$RC5"
fi
