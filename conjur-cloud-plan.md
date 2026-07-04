# Plan: Conjur Cloud (Secrets Manager SaaS) sibling repo

Goal: a full mirror of this lab's 9 cityapp integration methods, rebuilt against Secrets Manager SaaS (Conjur Cloud) instead of the self-hosted Enterprise Leader/Follower, as a **separate sibling repo** (matching [joetanx/conjur-k8s](https://github.com/joetanx/conjur-k8s) vs [joetanx/cjc-k8s](https://github.com/joetanx/cjc-k8s), the reference pair this plan is based on).

Prerequisites confirmed with the user: a real Conjur Cloud tenant is available, and it supports a non-interactive/service login for automation (not just the human username+password+MFA flow shown in joetanx's README) - so this can stay fully scripted like the rest of this repo, once we know the exact non-interactive auth mechanism the tenant offers.

## What carries over essentially unchanged

- `1.k8s-setup/` in full - cluster setup has nothing to do with which Secrets Manager flavor sits behind it.
- MySQL/world_db demo data setup.
- All three app image builds: `3.cityapp-setup/build/` (PHP), `4.cityapp-springboot/build/` (Java), `7.conjur-summon/build/` (Summon-wrapped PHP) - the apps themselves don't know or care whether Secrets Manager is self-hosted or SaaS.
- The *shape* of every consumption method's K8s manifests (volumeMounts, ServiceAccounts, container layout) - `secrets-provider-for-k8s`, ESO, the CSI provider, and Summon all already support pointing at Conjur Cloud instead of a self-hosted Follower; it's a config/connection change, not a mechanism change.

## What has to change

1. **`2.conjur-setup/` loses its Leader-provisioning half.** No `podman run conjur`, no `evoke configure leader`, no seed-fetcher. Replaced with `conjur init` / `conjur login` against the Conjur Cloud tenant URL (`https://<subdomain>.secretsmgr.cyberark.cloud/api`) using whatever non-interactive credential the tenant supports.
2. **No Follower in Kubernetes at all.** Every app talks directly to the Conjur Cloud endpoint over the internet. `11.deploying-follower-k8s.sh` and `follower/follower.yaml` have no equivalent - this also means the sibling repo's "single VM" can no longer be treated as self-contained/offline; it needs reliable outbound internet access to `*.secretsmgr.cyberark.cloud`.
3. **Policy branch structure changes.** Conjur Cloud segregates policy into `data` (hosts/groups/variables, `conjur policy load -b data -f ...`) and `conjur/authn-jwt` (authenticator definitions, `-b conjur/authn-jwt`) branches, instead of our flat `-b root` convention. Every `conjur policy load` call across folders 2, 5, 6, 7 needs its `-b` argument reconsidered.
4. **Variable path convention changes.** Our `test/CityApp/DBAccount/*` (and `test/CityAppESO/DBAccountESO/*`) paths assume a `test/`-rooted policy tree. Conjur Cloud's examples root everything under `data/` instead - this cascades into every YAML annotation, env var, and `ExternalSecret`/`SecretProviderClass` reference across folders 3-8, the same shape of change as the recent Safe/Account/property rename, just with a different prefix and spread across a second repo.
5. **Cert handling gets simpler.** Conjur Cloud's TLS cert is a real public cert - `openssl s_client -connect <tenant>.secretsmgr.cyberark.cloud:443 -showcerts` extracts it directly, no self-signed cert generation needed anywhere.
6. **Enabling the JWT authenticator gets simpler.** `conjur authenticator enable --id authn-jwt/<id>` replaces editing `/etc/conjur/config/conjur.yml` + `evoke configuration apply`.
7. **Folder 8 (rotate-password)'s MySQL steps are unaffected** (that's cityapp's own DB, unrelated to Conjur's backend) - only the `conjur variable set` calls need the updated path prefix.

## Suggested build order (once scoped in detail)

1. Confirm the tenant's non-interactive login mechanism first - this is the one unknown that everything else depends on.
2. Stand up the new repo's `1.k8s-setup/` (straight copy) and `2.conjur-setup/` rewritten for Conjur Cloud login + policy branches.
3. Port folder 3 (cityapp-setup: hardcode, push-to-file, push-to-k8s-secret, push-to-k8s-secret-init) - the smallest, most direct translation, proves the connection/cert/path changes work end-to-end before porting the rest.
4. Port folders 4 (springboot), 5 (ESO), 6 (CSI), 7 (Summon) - each mostly a config/path port once folder 3's pattern is validated.
5. Port folder 8 (rotate-password) last, since it depends on every app from 3-7 already being deployed.

## Non-interactive auth: reusable assets found in `cybr-emea-channelse/cybr-secretshub-full-workflow`

That project (Secrets Hub / Privilege Cloud focused, no existing Conjur Cloud code) already has a working, reusable pattern for exactly the "how do we log in without a human typing an MFA code" problem this plan depends on:

- **Getting a token (`pcloud-reconcile-api/test-reconcile.sh`, lines 92-124):** a plain `curl` OAuth2 `client_credentials` request -
  ```
  POST https://<identity-subdomain>.id.cyberark.cloud/oauth2/platformtoken
  Content-Type: application/x-www-form-urlencoded
  grant_type=client_credentials&client_id=<service-user>@cyberark.cloud.<tenant>&client_secret=<sa-secret>
  ```
  returns a Bearer `access_token`, subsequently used as `Authorization: Bearer <token>` against a CyberArk SaaS REST API (Privilege Cloud, in that script). Since Conjur Cloud sits behind the same CyberArk Identity tenant as every other ISPSS product, this exact token-fetch step is very likely reusable as-is for Conjur Cloud's REST API v2 too - worth testing directly rather than re-deriving.
- **Creating the service user itself (`pcloud-reconcile-api/main.tf`):** Terraform's `cyberark/idsec` provider, resource `idsec_identity_user` with `is_service_user = true` and `is_oauth_client = true`, plus `idsec_identity_role_member` to grant it a role (that project grants a Privilege Cloud admin role - we'd need the equivalent Conjur Cloud role name). Reusable wholesale as the "provision the automation identity" step, just needs the right role name substituted.
- **Gotcha already documented in that project's own CLAUDE.md, worth carrying over:** `idsec` provider `>= 0.4` requires a valid RFC-format `email` on `idsec_identity_user` - the Identity username itself (`...@cyberark.cloud.<tenant>`) fails email validation, so a separate `email` value must be supplied.
- **Strong lead, not yet confirmed:** Conjur Cloud's CLI setup doc (`cli-setup-new.htm`) says `conjur login` prompts for "your username and Secrets Manager access token" - notably *not* "password" or an MFA step. That phrasing is consistent with feeding it the same Identity OAuth2 access token obtained above as the login credential for a service-user identity (self-hosted `conjur login` already supports non-interactive `-i`/`-p` flags for exactly this shape of use). If confirmed true, both the CLI and the REST API v2 could be driven off one identical token-fetch step, and API-vs-CLI becomes a simple style choice rather than a capability question.

**This needs live verification against the real tenant, not more doc research** - the CLI/REST API v2 doc pages are JS-rendered landing pages whose actual command/endpoint tables didn't come through a plain fetch. Decided with the user: leave this as the next concrete step when picking this plan back up, rather than chasing it further via more doc-scraping attempts.

## Open items to resolve before starting

- **Verify live**, using the OAuth2 token-fetch pattern above against the real tenant: does `conjur login -i <sa-user> -p <access_token>` actually work non-interactively? Does the same Bearer token work directly against REST API v2 endpoints? This single test resolves both the login-mechanism question and the API-vs-CLI choice (undecided - "not sure yet, decide after verifying login mechanism" per the user).
- The Conjur Cloud role name to grant the service user via `idsec_identity_role_member` (equivalent to the Privilege Cloud admin role used in the reused project) - needed for the Terraform service-user provisioning step to actually grant Conjur Cloud access.
- New variable-path prefix to use under `data/` (mirroring `CityApp/DBAccount/...` under `test/` today).
- New sibling repo name (not yet decided).
- Whether the CSI provider's dual-authenticator pattern (`authn-jwt/k8s` + `authn-jwt/k8s-csi`, folder 6) is supported the same way on Conjur Cloud - not yet verified against docs.
