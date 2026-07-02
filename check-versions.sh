#!/bin/sh
# Checks every version pinned across the lab's folders against its current
# upstream release, and reports drift. Run this occasionally (e.g. before
# asking for a refresh pass) instead of re-discovering staleness by hand.
#
# Requires: curl, jq. Works with no/limited internet - a check that can't
# reach its registry is reported as MANUAL, not fatal, so the rest still runs.
#
# This is a maintenance tool, not part of the numbered lab pipeline: it has
# no 00.config.sh, no READY gate, and never modifies any file.

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT" || exit 1

PASS=0
STALE=0
MANUAL=0
PINNED=0
TIMEOUT=10

# --- helpers -----------------------------------------------------------

print_row() {
    printf "%-7s %-42s %-16s %-16s %s\n" "$1" "$2" "$3" "$4" "$5"
}

# report <label> <current> <latest> <note>
# latest="" means the registry couldn't be reached or had no usable answer.
report() {
    label="$1"; current="$2"; latest="$3"; note="$4"
    if [ -z "$latest" ]; then
        print_row "MANUAL" "$label" "$current" "?" "${note:-could not reach registry - check manually}"
        MANUAL=$((MANUAL + 1))
    elif [ "$current" = "$latest" ]; then
        print_row "OK" "$label" "$current" "$latest" "$note"
        PASS=$((PASS + 1))
    else
        print_row "STALE" "$label" "$current" "$latest" "$note"
        STALE=$((STALE + 1))
    fi
}

# pinned <label> <current> <reason>
# For versions deliberately capped below "latest" - not a drift to report.
pinned() {
    print_row "PINNED" "$1" "$2" "-" "$3"
    PINNED=$((PINNED + 1))
}

github_latest_tag() {
    # github_latest_tag <owner/repo>
    curl -fsSL --max-time "$TIMEOUT" "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
        | jq -r '.tag_name // empty' 2>/dev/null
}

dockerhub_tags() {
    # dockerhub_tags <namespace/repo> [name-filter]
    filter=""
    [ -n "$2" ] && filter="&name=$2"
    curl -fsSL --max-time "$TIMEOUT" "https://hub.docker.com/v2/repositories/$1/tags?page_size=100${filter}" 2>/dev/null \
        | jq -r '.results[].name' 2>/dev/null
}

# dockerhub_alias_target <namespace/repo> <alias-tag> <numeric-pattern>
# Resolves a floating alias (e.g. "lts") to whichever numeric tag currently
# shares its digest, since alias digests get rebuilt often but the version
# tag they point to only changes when the upstream project moves the line.
dockerhub_alias_target() {
    digest=$(curl -fsSL --max-time "$TIMEOUT" "https://hub.docker.com/v2/repositories/$1/tags/$2" 2>/dev/null | jq -r '.digest // empty' 2>/dev/null)
    [ -z "$digest" ] && return
    curl -fsSL --max-time "$TIMEOUT" "https://hub.docker.com/v2/repositories/$1/tags?page_size=100" 2>/dev/null \
        | jq -r --arg d "$digest" '.results[] | select(.digest==$d) | .name' 2>/dev/null \
        | grep -E "$3" | sort -t. -k1,1n -k2,2n | tail -1
}

maven_latest_release() {
    # maven_latest_release <groupId-with-slashes> <artifactId>
    curl -fsSL --max-time "$TIMEOUT" "https://repo1.maven.org/maven2/$1/$2/maven-metadata.xml" 2>/dev/null \
        | grep -oE '<release>[^<]+</release>' | sed -E 's#</?release>##g'
}

helm_repo_latest() {
    # helm_repo_latest <index.yaml URL> <chart name>
    # Helm index.yaml lists each chart's versions newest-first, but "version:"
    # is the last field in each entry - not near the top - so this isolates
    # the whole first entry block before pulling "version:" out of it.
    curl -fsSL --max-time "$TIMEOUT" "$1" 2>/dev/null \
        | awk -v chart="  ${2}:" 'index($0,chart)==1{f=1;next} f&&/^  [a-zA-Z]/{exit} f' \
        | grep -m1 '^    version:' | awk '{print $2}'
}

echo "Checking pinned versions against upstream latest (repo: $REPO_ROOT)"
echo
print_row "STATUS" "COMPONENT" "PINNED" "LATEST" "NOTE"
print_row "------" "---------" "------" "------" "----"

# --- 1.k8s-setup ---------------------------------------------------------

k8s_current=$(grep -m1 '^K8S_VERSION=' 1.k8s-setup/00.config.sh | cut -d= -f2)
k8s_latest_full=$(curl -fsSL --max-time "$TIMEOUT" https://dl.k8s.io/release/stable.txt 2>/dev/null)
k8s_latest=$(echo "$k8s_latest_full" | grep -oE '^v[0-9]+\.[0-9]+')
report "K8S_VERSION (kubelet/kubeadm/kubectl+CRI-O)" "$k8s_current" "$k8s_latest" "1.k8s-setup/00.config.sh - CRI-O must match this"

dash_current=$(grep -oE "kubernetesui/dashboard:v[0-9.]+" 1.k8s-setup/yaml/kube-dashboard.yaml | head -1 | cut -d: -f2)
pinned "Kubernetes Dashboard" "$dash_current" "capped at v2 - v3 needs Helm+cert-manager, see CLAUDE.md"

# --- 2.conjur-setup --------------------------------------------------------

appliance_current=$(grep -m1 '^conjur_version=' 2.conjur-setup/00.config.sh | cut -d= -f2)
report "Secrets Manager appliance" "$appliance_current" "" "licensed download - check the Idira portal manually"

seedfetcher_current=$(grep -oE "dap-seedfetcher:[0-9.]+" 2.conjur-setup/follower/follower.yaml | cut -d: -f2)
seedfetcher_latest=$(dockerhub_tags cyberark/dap-seedfetcher | grep -E '^[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n | tail -1)
report "dap-seedfetcher" "$seedfetcher_current" "$seedfetcher_latest" "2.conjur-setup/follower/follower.yaml"

mysql_current=$(grep -oE "mysql:[0-9.]+" 2.conjur-setup/02.running-mysql-db.sh | head -1 | cut -d: -f2)
mysql_lts=$(dockerhub_alias_target library/mysql lts '^[0-9]+\.[0-9]+$')
report "MySQL (LTS line)" "$mysql_current" "$mysql_lts" "2.conjur-setup/02.running-mysql-db.sh"

# --- 3.cityapp-setup --------------------------------------------------------

secretsprov_current=$(grep -m1 -oE "secrets-provider-for-k8s:[0-9.]+" 3.cityapp-setup/yaml/cityapp-conjurtok8sfile.yaml | cut -d: -f2)
secretsprov_latest=$(github_latest_tag cyberark/secrets-provider-for-k8s | sed 's/^v//')
report "secrets-provider-for-k8s" "$secretsprov_current" "$secretsprov_latest" "3.cityapp-setup/yaml/*.yaml (3 files)"

php_current=$(grep -oE "php:[0-9.]+-apache" 3.cityapp-setup/build/Dockerfile | cut -d: -f2)
php_latest=$(dockerhub_tags library/php apache | grep -E '^[0-9]+\.[0-9]+-apache$' | sort -t. -k1,1n -k2,2n | tail -1)
report "PHP base image" "$php_current" "$php_latest" "3.cityapp-setup/build/Dockerfile"

# --- 4.cityapp-springboot ---------------------------------------------------

sdk_current=$(grep -A1 '<artifactId>conjur-sdk-springboot</artifactId>' 4.cityapp-springboot/build/pom.xml | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
sdk_latest=$(maven_latest_release com/cyberark conjur-sdk-springboot)
report "conjur-sdk-springboot (Maven)" "$sdk_current" "$sdk_latest" "4.cityapp-springboot/build/pom.xml"

tomcat_current=$(grep -oE "tomcat:[0-9.]+-jre[0-9]+" 4.cityapp-springboot/build/Dockerfile | cut -d: -f2)
tomcat_jre=$(echo "$tomcat_current" | grep -oE 'jre[0-9]+')
tomcat_latest=$(dockerhub_tags library/tomcat 9.0 | grep -E "^9\.0\.[0-9]+-${tomcat_jre}\$" | sort -t. -k3,3n | tail -1)
report "Tomcat base image (9.0.x line)" "$tomcat_current" "$tomcat_latest" "4.cityapp-springboot/build/Dockerfile - Tomcat 10 needs the Spring Boot 3 migration"

springboot_current=$(grep -A2 'spring-boot-starter-parent' 4.cityapp-springboot/build/pom.xml | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
pinned "Spring Boot" "$springboot_current" "OSS EOL since 2023-06-30, known tech debt - see CLAUDE.md, needs a Jakarta migration to move"

# --- 5.conjur-eso ------------------------------------------------------------

eso_current=$(grep -oE -- "--version [0-9.]+" 5.conjur-eso/00.installing-eso-helm.sh | awk '{print $2}')
eso_latest=$(github_latest_tag external-secrets/external-secrets | sed 's/^helm-chart-//')
report "external-secrets Helm chart" "$eso_current" "$eso_latest" "5.conjur-eso/00.installing-eso-helm.sh"

# --- 6.conjur-csi ------------------------------------------------------------

csidriver_current=$(grep -m1 -oE -- "--version [0-9.]+" 6.conjur-csi/00.installing-csi-helm.sh | awk '{print $2}')
csidriver_latest=$(helm_repo_latest https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts/index.yaml secrets-store-csi-driver)
report "secrets-store-csi-driver Helm chart" "$csidriver_current" "$csidriver_latest" "6.conjur-csi/00.installing-csi-helm.sh"

csiprovider_current=$(grep -m1 -oE -- "--version [0-9.]+" 6.conjur-csi/03.installing-conjur-csi-provider.sh | awk '{print $2}')
csiprovider_latest=$(helm_repo_latest https://cyberark.github.io/helm-charts/index.yaml conjur-k8s-csi-provider)
report "conjur-k8s-csi-provider Helm chart" "$csiprovider_current" "$csiprovider_latest" "6.conjur-csi/03.installing-conjur-csi-provider.sh"

# --- summary -----------------------------------------------------------

echo
echo "OK: $PASS   STALE: $STALE   MANUAL: $MANUAL   PINNED (intentional): $PINNED"
[ "$STALE" -gt 0 ] && echo "Review the STALE rows above and decide whether to bump them - this script never edits files itself."

exit 0
