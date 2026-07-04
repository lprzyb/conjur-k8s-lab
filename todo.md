# TODO / Backlog

Ideas for future lab additions, not yet scoped or scheduled.

- **Secrets Manager Cluster standby + failover**: add scripts to stand up Auto-Failover clustering (see the "Known architecture quirks" note in CLAUDE.md about the Leader/Follower page showing "Unknown" without it) and test an actual failover.
- **Vault Synchronizer**: install it silently, sync a secret from PAM, create a new workload/policy for it, and deploy a new cityapp variant that consumes the synced secret.
- **Split policy loading per-application**: instead of loading all demo policy up front (`2.conjur-setup/policies/demo-data.yaml`), load one policy per app as it's deployed - similar to how `5.conjur-eso/` already loads its own self-contained policy file. Brainstorm later, not scoped yet.
- **Fake ticketing portal**: a small web portal where a dev requests a new application; the backend creates the secret + policy in Secrets Manager, and the response gives the dev the variable paths to put in their deployment spec plus a choice of secrets-provider method.
- **Conjur Cloud (SaaS) sibling repo**: full mirror of all 9 cityapp methods rebuilt against Secrets Manager SaaS instead of self-hosted Enterprise - scoped as a separate sibling repo, tenant access and non-interactive login confirmed available. See [conjur-cloud-plan.md](./conjur-cloud-plan.md) for the detailed breakdown of what carries over vs. what must be rebuilt, and the open items to resolve before starting.

## Non-K8s use cases: Ansible / Terraform / Jenkins (scoped, ready to build)

Reference material found: [joetanx/conjur-ansible](https://github.com/joetanx/conjur-ansible), [joetanx/conjur-terraform](https://github.com/joetanx/conjur-terraform), [joetanx/conjur-jenkins](https://github.com/joetanx/conjur-jenkins), and [joetanx/conjur-gitlab](https://github.com/joetanx/conjur-gitlab) (bonus find, not originally on this list - see note at the bottom).

**The one thing to internalize before touching any of these**: all four reference repos are classic Conjur Enterprise on a standalone RHEL VM - none of them use Kubernetes, `authn-jwt/k8s`, or ServiceAccount tokens at all. Ansible authenticates with a static host API key (old-school `conjur.identity`/netrc file). Jenkins and GitLab each authenticate via JWT too, but the trust anchor is the *tool's own* JWKS endpoint (Jenkins' Secrets Plugin exposes one at `<jenkins-url>/jwtauth/conjur-jwk-set`; GitLab exposes one at `<gitlab-url>/-/jwks/`), not Kubernetes' OIDC issuer. That's actually a good fit for us: these three tools would run as VM-native processes/containers talking directly to our existing Secrets Manager **Leader** (same endpoint `2.conjur-setup/00.config.sh` already defines) - no new Follower needed, no K8s awareness needed. Each would add its own new `authn-jwt/<service-id>` webservice, separate from and unrelated to the existing `authn-jwt/k8s` used throughout folders 3-8.

Suggested build order: Ansible first (smallest, most self-contained, reuses our single-VM constraint elegantly), then Terraform (reuses infrastructure we already have - no new service to install), then Jenkins (most infra work - a new app, a cert/JWKS trust chain, and a plugin to install).

### 1. Ansible (`9.conjur-ansible/`, suggested)

**What's directly reusable from `joetanx/conjur-ansible`:** the whole shape of the demo. Install `ansible-core` + the `cyberark.conjur` collection, load a small Conjur policy (`ssh_keys` policy + `ansible` host), configure `/etc/conjur.conf` + `/etc/conjur.identity` (or the modern `cyberark.conjur` lookup plugin's own env-var config, worth checking which the collection prefers now vs. in their 2022-era README), then run a playbook whose tasks use `lookup('cyberark.conjur.conjur_variable', ...)`-style calls to fetch credentials before an SSH-based task runs.

**What has to change for our lab:**
- We have no second VM to be the "managed node" - the managed node has to be the lab VM itself (SSH to its own `LAB_IP`/`localhost`, or its own K8s-node hostname). A bit unusual as a security demo (SSHing into yourself), but harmless and still proves the point: Ansible has zero embedded credentials, Conjur is the only source of the SSH login.
- Reference repo uses SSH **key** auth (username + private key, generated fresh, public key dropped into `authorized_keys`). Decide: keep key auth (closer to the reference, marginally more setup - `ssh-keygen` + `authorized_keys`), or switch to password auth (simpler variable set, matches this lab's existing `address/username/password` Safe/Account/property convention already used for `test/CityApp/DBAccount/*`). Password auth is probably the better fit here for consistency with the rest of the repo.
- Suggested variable set: a new Safe, e.g. `test/VMAccess/SSHAccount/{address,username,password}` (or `.../sshkey` if key auth is chosen), following the same trimmed Safe/Account/property convention established for `test/CityApp/DBAccount/*`.
- Tasks to actually run once connected (per the ask): `hostname`, `date`, `podman ps -a` - registered and printed, so the playbook output visibly proves it reached the real VM using only Conjur-sourced credentials.
- Follow this repo's existing conventions: `00.config.sh` sourcing `../2.conjur-setup/00.config.sh` + its own `READY` gate, numbered scripts, `set -x`/`set +x` transcript blocks, colored Done/Next `printf` messages.

**Open decisions to make when picking this up:** password vs. SSH-key auth; whether the playbook should live inside this new folder or reuse an `ansible/` subfolder pattern like other folders' `yaml/`.

### 2. Terraform (`10.conjur-terraform/`, suggested)

**What's directly reusable from `joetanx/conjur-terraform`:** the core pattern of section 3 of their README - a `provider "conjur" {}` block plus `data "conjur_secret" "x" { name = "..." }` data sources, whose `.value` attributes feed straight into another provider's resource block. This is the actual reusable idea, completely decoupled from AWS.

**What has to change for our lab:** their demo's downstream provider is AWS (creating an S3 bucket) - we have no AWS account or credentials in this lab and shouldn't introduce one just for this. Per the original todo note, swap the downstream target for something we already have running:
- **Docker/podman provider** (`kreuzwerker/docker`, which talks to podman's Docker-compatible socket) - simplest option, no new infrastructure. Example: fetch `test/CityApp/DBAccount/*` from Conjur via the `conjur` provider, then use those values to launch or configure a throwaway container (e.g., a `mysql` client container pre-configured with the fetched DB creds, proving Terraform pulled real values).
- **Kubernetes provider** (`hashicorp/kubernetes`) - more interesting narratively, since it would let Terraform create/update a K8s Secret from Conjur-sourced values, giving a third way (alongside ESO in folder 5 and the Secrets Provider in folder 3) to get a Conjur secret into Kubernetes - worth calling out explicitly as "Terraform as an alternative to ESO" in the README when this gets built.
- Skip their GitLab-integrated Terraform scenario (section 4) entirely unless the GitLab use case below also gets built - it depends on GitLab CI's own JWT plugin flow.
- New Conjur policy needed: a `terraform` policy + host (mirroring their `tf-vars.yaml`), granted read access to whatever variable set gets used (reuse `test/CityApp/DBAccount/*`, or a new dedicated Safe if the Kubernetes-provider path is chosen and a distinct demo Secret name/value is wanted).

**Open decisions to make when picking this up:** Docker/podman provider vs. Kubernetes provider (leaning Kubernetes for the strongest tie-in to the rest of this lab); whether to reuse `test/CityApp/DBAccount/*` or create a Terraform-specific variable set.

### 3. Jenkins (`11.conjur-jenkins/`, suggested - most infra work)

**What's directly reusable from `joetanx/conjur-jenkins`:** the whole JWT trust-chain concept (Jenkins Secrets Plugin JWKS ↔ Conjur `authn-jwt/jenkins` webservice), the two example pipelines (a MySQL one and an AWS-CLI one), and the general shape of "install Jenkins → install Conjur Secrets Plugin → configure JWT → create a pipeline using `withCredentials([conjurSecretCredential(...)])`".

**What has to change for our lab:**
- Their guide installs Jenkins via RPM directly on the OS and configures HTTPS with a personal CA's cert (`jenkins.vx.pfx`). This repo's own style leans toward podman containers for auxiliary services (MySQL and the Secrets Manager Leader both run as podman containers already) - worth deciding whether to install Jenkins as a podman container instead of an RPM service, for consistency, though the official Jenkins Docker image would need its own TLS termination worked out either way.
- **Certificate trust is the fiddly part.** Conjur needs to trust Jenkins' HTTPS certificate to fetch its JWKS (`conjur/authn-jwt/jenkins/ca-cert` variable). This repo doesn't have a standing CA - but it already has a working pattern for exactly this shape of problem: `2.conjur-setup/10.loading-k8s-follower-configmap.sh` extracts a live TLS cert with `openssl s_client -showcerts -connect ... | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p'`. The same trick works in reverse here: generate a self-signed cert for Jenkins, configure Jenkins to serve HTTPS with it, then extract that live cert the same way and set it as `conjur/authn-jwt/jenkins/ca-cert`. No new CA infrastructure needed.
- No AWS CLI demo (same reasoning as Terraform, above) - keep only a MySQL-flavored pipeline, and better yet, point it at this lab's *own* `mysqldb` podman container and reuse `test/CityApp/DBAccount/*` directly instead of inventing new demo data. That means zero new demo secrets need to be created - only a new `authn-jwt/jenkins` webservice + host identity granted read access to the existing variable set.
- Plugin install and pipeline creation should be scripted, not done by hand through the UI (unlike the reference repo's screenshots) - Jenkins' own CLI (`jenkins-plugin-cli` for the plugin, or the `java -jar jenkins-cli.jar` / REST `createItem` API with a pipeline XML/Jenkinsfile for the job) can drive both steps non-interactively, matching this repo's "everything is a numbered script" convention.

**Open decisions to make when picking this up:** Jenkins as a podman container vs. RPM install; whether to automate Conjur Secrets Plugin *configuration* (not just install) via Jenkins' Configuration-as-Code (JCasC) plugin, which would make the whole folder fully hands-off like everything else in this repo, or leave one manual UI step documented (closer to the reference repo, less scripting risk).

### Bonus, not yet planned: GitLab (`joetanx/conjur-gitlab`)

Not part of the original ask, but the user found this repo alongside the other three. It documents the same JWT-trust pattern as Jenkins, but anchored on GitLab CI's own built-in `CI_JOB_JWT_V2` (automatically present in every pipeline job, no separate plugin needed) and GitLab's own JWKS endpoint (`<gitlab-url>/-/jwks/`). If a GitLab use case is ever wanted, it would need its own full GitLab CE install on the VM (a genuinely heavy addition, heavier than Jenkins) and would unlock the GitLab-integrated Terraform scenario noted above for free. Worth a deliberate go/no-go conversation with the user before scoping it - not committed to this list yet, listed here only so the reference isn't lost.
