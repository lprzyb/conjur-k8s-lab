# TODO / Backlog

Ideas for future lab additions, not yet scoped or scheduled.

- **Secrets Manager Cluster standby + failover**: add scripts to stand up Auto-Failover clustering (see the "Known architecture quirks" note in CLAUDE.md about the Leader/Follower page showing "Unknown" without it) and test an actual failover.
- **Vault Synchronizer**: install it silently, sync a secret from PAM, create a new workload/policy for it, and deploy a new cityapp variant that consumes the synced secret.
- **Jenkins use case**: deploy Jenkins, install the Conjur plugin, and create an example pipeline that pulls a secret - all scripted.
- **Ansible use case**: add Ansible and a simple playbook that takes address/username/password from Secrets Manager, SSHes into the VM, and pulls some data back (hostname, date, `podman ps -a`).
- **Terraform use case**: add Terraform with the Secrets Manager provider alongside something meaningful in this lab's context - probably the Kubernetes provider or the Docker/podman provider (TBD).
- **Split policy loading per-application**: instead of loading all demo policy up front (`2.conjur-setup/policies/demo-data.yaml`), load one policy per app as it's deployed - similar to how `5.conjur-eso/` already loads its own self-contained policy file. Brainstorm later, not scoped yet.
- **Fake ticketing portal**: a small web portal where a dev requests a new application; the backend creates the secret + policy in Secrets Manager, and the response gives the dev the variable paths to put in their deployment spec plus a choice of secrets-provider method.
