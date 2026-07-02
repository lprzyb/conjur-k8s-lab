# Building standalone Idira Secrets Manager Enterprise and K8s LAB
*(Idira Secrets Manager was formerly known as CyberArk Conjur - this README uses the current names throughout, except where quoting real filenames, URLs, CLI commands, or literal program output that still use the older "Conjur"/"CyberArk" names.)*

This project will help you to quickly build up the standalone, single VM lab environment to test Secrets Manager and k8s application integration including:
- Secrets Manager follower in kubernetes
- k8s jwt authentication
- Secrets Manager push to k8s file
- Secrets Manager push to kubernetes secret
- native Secrets Manager Spring Boot SDK integration (no sidecar)
- External Secrets Operator (ESO) integration
- Secrets Manager CSI provider integration
- and other

All setup, installing and configuration steps are all put in sequence of scripts to make the setup process quicker and easier

### Credits
This is an updated and polished fork of the original lab by Huy Do (huy.do@cyberark.com), based on the installing/configuration guide by Joe Tan (joe.tan@cyberark.com, https://github.com/joetanx). Kudos to both for the original work this builds on.

### Video on step by step setting up the original lab is at https://youtu.be/qiXBtv5R1z4
(some details - script names, base OS, a few added demos - have since changed in this fork, but the core flow still applies)

### Keeping this lab current
Run ```./check-versions.sh``` (needs ```curl``` and ```jq```) any time before rebuilding the lab to see which pinned image/chart/dependency versions are behind their current upstream release. It only reports drift - it never edits any file.

# PART I: SETING UP ENVIRONMENT
# 1.1. LAB Prerequisites
- ESXI server or VMWorkstation to create standalone lab VM as below:
  - 12GB RAM (minimum), recommended 16GB
  - 2 vCore CPU
  - 60GB HDD
  - Rocky Linux 9 base OS (Minimal Install)
    - Hostname: k8s.demo.local
    - LAN IP (eg 172.16.100.15/24)
    - Internet connection to do yum updating and packages installation
- Secrets Manager appliance image:
  - Contact Idira local representative for the appliance tarball (e.g. conjur-appliance-Rls-v13.9.0.tar.gz)
  - Idira softwares and related tools can be downloaded at https://cyberark-customers.force.com/mplace/s/#software
  - The Secrets Manager CLI is installed automatically by ```2.conjur-setup/06.installing-conjur-cli.sh``` (downloads [conjur-cli-go](https://github.com/cyberark/conjur-cli-go) from GitHub) - no manual download needed
- Java 17 (needed to build the Spring Boot cityapp in Part III.5 / ```4.cityapp-springboot```): saves time later to install it upfront with ```sudo dnf install -y java-17-openjdk java-17-openjdk-devel``` - not strictly required here, ```4.cityapp-springboot/41.building-cityapp-image.sh``` also installs it automatically if you skip this step

 *The IP addresses in this document are using from current lab environment. Please replace the **172.16.100.109** by your actual **VM IP**’s
    
# 1.2. VMs Preparation
## **Step1.2.1: Preparing Rocky Linux 9**
Rocky Linux 9 can be downloaded at https://rockylinux.org/download - grab the latest 9.x Minimal ISO.

![centos](./images/01.centos-download.png)

*(screenshots below are from the original CentOS Stream 9-based walkthrough - the Rocky Linux download page and Anaconda installer look and work the same way, just rebranded)*

Creating VM and installing with minimal install option

![minimal](./images/02.minimal-install.png)

**Every command in this README assumes an actual root shell**, not `sudo <command>` run one at a time as a regular user. If you installed with a personal admin account (e.g. one created on the Anaconda user-creation screen) rather than enabling direct root login, get a root shell once and stay there for the rest of the lab:
```
sudo -i
```
Running individual commands as `sudo <cmd>` from a non-root user instead of this will eventually hit a permission error somewhere downstream - e.g. `git clone` in Step1.2.3 failing to write into `/opt/lab` because only the `sudo`-prefixed commands were actually root, not the shell itself. `sudo -i` avoids that entirely.

Once you're logged in to a freshly installed VM as root, a few one-liners before anything else:
```
#Set the hostname the rest of this lab expects
hostnamectl set-hostname k8s.demo.local

#Update the base OS
yum update -y

#Install the handful of tools the setup scripts assume are already present
#(openssl/tar/gzip ship with Minimal Install by default - listed for completeness)
yum -y install git curl jq openssl
```
Checking for IP, DNS and Internet connection
```
ip a
ping -c1 8.8.8.8
```

Checking sshd allows both password and SSH key login (useful if you'll be connecting from more than one workstation, or don't have a key handy yet) - Rocky/RHEL 9 split sshd config across drop-in files under `/etc/ssh/sshd_config.d/`, so check the *effective* config rather than grepping `sshd_config` alone:
```
sshd -T | grep -iE "^(passwordauthentication|pubkeyauthentication)"
```
If either comes back other than `yes`, enable both explicitly and restart sshd:
```
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
systemctl restart sshd
```
Note this widens auth options (password login is more brute-forceable than key-only) - fine for an isolated lab VM, but worth being deliberate about if this VM is reachable beyond your own network.
## **Step1.2.2: Copying files for setting up**
Create the setup_files folder:
```
mkdir -p /opt/lab/setup_files
chmod 755 /opt/lab/setup_files
```
Copy Secrets Manager appliance image file to setup_files folder
- Secrets Manager docker image: conjur-appliance-Rls-v13.9.0.tar.gz (or whatever version you received from Idira)
## **Step1.2.3: Cloning git hub repo**
This repo is public, so no GitHub auth is needed to clone it.
```
cd /opt/lab
git clone https://github.com/lprzyb/conjur-k8s-lab.git
```
Installation folder contains 6 sub folders for different setup
- 1.k8s-setup: scripts to setup k8s standalone cluster environment
- 2.conjur-setp: scripts to install podman, mysql, Secrets Manager leader containers and deploying Secrets Manager follower in k8s
- 3.cityapp-setup: scripts to deploy different types of cityapp application (hardcode, push-to-file, push-to-secret, springboot)
- 4.cityapp-springboot: builds the Spring Boot cityapp image and deploys it via the native Secrets Manager SDK (no sidecar)
- 5.conjur-eso: installs and configures the External Secrets Operator
- 6.conjur-csi: installs and configures the Secrets Manager CSI provider

Each folder will have ```00.config.sh``` which contains some parameters. Review file content, change all related parameters to actual value and set ```READY=true``` before doing further steps.

# 1.3. (Optional) DNS / hosts file on your workstation
Browsing straight to ```http://<VM-IP>:PORT``` (as the rest of this README does) always works, no setup needed. But the Conjur Leader's TLS certificate is issued for ```conjur-leader.demo.local``` and ```conjur.demo.local``` (its ```-h```/```--leader-altnames``` in ```2.conjur-setup/05.configuring-conjur-leader.sh```), not for its IP - so visiting ```https://<VM-IP>/``` shows an extra "hostname mismatch" warning on top of the expected "self-signed, untrusted" one. Mapping the hostname on your own workstation clears that up. As a bonus, the landing page's links auto-adapt to whatever hostname you used to reach it (see ```1.k8s-setup/yaml/landing-page.html```) - visit it via ```k8s.demo.local``` and every link it generates will use that name too, instead of the raw IP.

Add to your workstation's hosts file (```/etc/hosts``` on macOS/Linux, ```C:\Windows\System32\drivers\etc\hosts``` on Windows, admin/root privileges required) or your lab's DNS server if you have one:
```
<VM-IP>  k8s.demo.local
<VM-IP>  conjur-leader.demo.local
<VM-IP>  conjur.demo.local
```
Replace ```<VM-IP>``` with your actual VM IP (```CONJUR_IP``` in ```2.conjur-setup/00.config.sh```). If you changed ```LAB_DOMAIN``` away from the ```demo.local``` default, use that value instead throughout.

This doesn't help the K8s Dashboard or the Secrets Manager Follower's own endpoint - both present generic self-signed certs not bound to any particular hostname, so you'll still see the "untrusted" warning there regardless of how you address them.

*macOS note: ```.local``` names are also handled by Bonjour/mDNS - a static hosts file entry still takes priority, but if you ever see stale/conflicting resolution, that's why.*

# PART II: SETING UP CONJUR - K8S LAB
# 2.1. Setting up K8s standalone cluster
## **Step2.1.0: Reviewing 00.config.sh**
```
cd /opt/lab/conjur-k8s-lab/1.k8s-setup
vi 00.config.sh
```
Set ```K8S_VERSION``` to the Kubernetes/CRI-O minor version to install (e.g. ```v1.35```) and set ```READY=true``` to continue. CRI-O and kubelet/kubeadm/kubectl must use the same minor version.

## **Step2.1.1: Installing cri-o**
```
./01.installing-cri-o.sh
```
Checking crio service after done to make sure crio is up and run
```
service crio status
```

## **Step2.1.2: Installing kubelet kubeadm and kubectl**
```
./02.installing-k8s-and-tools.sh
```

## **Step2.1.3: Setting up cluster and networking**
```
./03.creating-k8s-cluster.sh 
```
Make sure that cni0 interface is getting correct IP (in 10.244) before doing futher steps
```
ip address show dev cni0 | grep 10.244
```
Checking for the kubelet service status and cluster info
```
service kubelet status
kubectl get all
```

## **Step2.1.4: Setting up kubernetes dashboard**
```
./04.installing-k8s-dashboard.sh
```
Copy the value of service account token to notepad for later usage. Checking status of k8s dashboard deployment
```
kubectl -n kubernetes-dashboard get pods -o wide
```
Open browser and login to k8s dashboard using previous copied token
```
https://<VMIP>:30443
```

![k8sd1](./images/03.k8s-dashboard1.png)

Select kube-system namespace and review some of the data in dashboard

![k8sd2](./images/04.k8s-dashboard2.png)

## **Step2.1.5: Deploying the demo landing page**
```
./05.deploying-landing-page.sh
```
Deploys a single static page (plain HTML/CSS, no JS framework) with links to every demo you'll deploy in the following parts. Open it now and keep the tab open - links to demos you haven't deployed yet just won't connect until you get there.
```
http://<VM-IP>:30001
```

# 2.2. Setting up podman and Secrets Manager environment
## **Step2.2.1: Reviewing 00.config.sh**
```
cd /opt/lab/conjur-k8s-lab/2.conjur-setup
vi 00.config.sh
```
Changed all related parameters such as IP, domain, password... and set ```READY=true``` to continue

## **Step2.2.2: Installing podman**
```
./01.installing-podman.sh
```
Using ```podman image ls``` to check current podman images

## **Step2.2.3: Setting up mysql container and database**
```
./02.running-mysql-db.sh
```
Using command ```podman container ls``` to make sure mysql container is up and running.
Using command ```ping mysql.demo.local``` to make sure host entry has been added correctly

## **Step2.2.4: Installing Secrets Manager leader**
```
./03.loading-conjur-images.sh
./04.starting-conjur-container.sh
./05.configuring-conjur-leader.sh
```
Using command ```podman image ls | grep conjur``` to make sure that image is loaded correctly

Using command ```podman container ls``` to make sure that conjur1 container is up and running

Using command ```curl -k https://conjur-leader.demo.local/info``` to check conjur leader status

Using browser and put in Secrets Manager leader URL ```https://<VMIP>```, login using user admin and password was set in ```00.config.sh``` file
```
https://<VM-IP>/
```

![conjurgui](./images/05.conjur-gui.png)

## **Step2.2.5: Installing Secrets Manager CLI**
```
./06.installing-conjur-cli.sh
```

The script installs the [conjur-cli-go](https://github.com/cyberark/conjur-cli-go) binary, runs ```conjur init self-hosted``` (self-signed cert trusted automatically via ```-s```), then ```conjur login``` - enter the admin password when prompted.

Using command ```conjur whoami``` to doublecheck the result.

## **Step2.2.6: Loading demo data and enable conjur-k8s-jwt authentication**
```
./07.loading-demo-data.sh
./08.enable-k8s-jwt-authenticator.sh
```
Using ```curl -k https://conjur-leader.demo.local/info``` to see the authenticaion options that are enabled.
```
...
  "authenticators": {
    "installed": [
      "authn",
      "authn-azure",
      "authn-gcp",
      "authn-iam",
      "authn-jwt",
      "authn-k8s",
      "authn-ldap",
      "authn-oidc"
    ],
    "configured": [
      "authn",
      "authn-jwt/k8s"
    ],
    "enabled": [
      "authn",
      "authn-jwt/k8s"
...    
```
Running below command to load jwt data to Secrets Manager environment
```
./09.loading-conjur-jwt-data.sh 
```
Using browser, login to Secrets Manager GUI to review the demo data and content. Make sure all authn-jwt/k8s secrets got values
- conjur/authn-jwt/k8s/audience: jwt audience, should be ```cybrdemo``` by default.
- conjur/authn-jwt/k8s/identity-path: jwt path for identity, should be ```jwt-apps/k8s``` by default.
- conjur/authn-jwt/k8s/issuer: jwt issuer, should be ```https://kubernetes.default.svc.cluster.local``` by default
- conjur/authn-jwt/k8s/public-keys: k8s public key information, should be in json format.

![conjurgui](./images/06.conjur-data.png)

If any of above parameters is emply, please run script ```./09.loading-conjur-jwt-data.sh``` again.

## **Step2.2.7: Deploying Secrets Manager follower on k8s**
```
./10.loading-k8s-follower-configmap.sh 
./11.deploying-follower-k8s.sh 
```
Login to k8s dashboard, select namespace conjur and checking for follower deployment and pod status

![conjurgui](./images/07.k8s-follower-data.png)

Login to Secrets Manager GUI, go to ```seting>Secrets Manager Cluster``` to check for follower status
![conjurgui](./images/08.conjur-follower.png)

Using command ```curl -k https://<VM-IP>:30444/info``` to check for follower detai info
```
...
  "authenticators": {
    "installed": [
      "authn",
      "authn-azure",
      "authn-gcp",
      "authn-iam",
      "authn-jwt",
      "authn-k8s",
      "authn-ldap",
      "authn-oidc"
    ],
    "configured": [
      "authn",
      "authn-jwt/k8s"
    ],
    "enabled": [
      "authn-jwt/k8s"
    ]
...
```

### A note on the Secrets Manager Cluster page's "Unknown" Follower status
The Follower's Services/Database/Free Space columns on the Secrets Manager Cluster
page (Step2.2.7 above) show "Unknown" out of the box, and its Domain Name
column shows ```host.containers.internal``` instead of anything meaningful -
this is expected for this lab's topology, not a bug, and the original repo's
own reference screenshot shows the identical result.

This lab configures a plain Leader + Follower replication setup
(```05.configuring-conjur-leader.sh``` runs ```evoke configure leader``` with
no ```--auto-failover```/etcd cluster flags), not Secrets Manager Enterprise's separate
Auto-Failover clustering feature - which is why the Leader's own row shows
```Auto-failover: N/A``` too. The Follower's Services/Database/Free Space
status specifically depends on Auto-Failover's etcd-based health-monitoring
agent, which isn't configured here; its Replication status still shows real
data because that comes from Postgres's own replication view, not the
missing agent. The Domain Name/Host IP columns come from a reverse DNS
lookup on the connection's source address rather than the node's own
hostname - for the Follower that source is podman's own NAT gateway address
(this lab runs the Leader and Follower on the same VM, so the Follower
reaches the Leader via the VM's external IP, which loops back through
podman's port-publishing NAT), the same class of artifact the page's own
disclaimer describes for a load balancer.

# PART III: TESTING CITYAPP OPTIONS
# 3.1. Building cityapp image
## **Step3.1.1: Reviewing 00.config.sh**
```
cd /opt/lab/conjur-k8s-lab/3.cityapp-setup
vi 00.config.sh
```
Changed all related parameters such as IP, domain... and set ```READY=true``` to continue
## **Step3.1.2: Building image**
Review the cityapp image detail on /opt/lab/conjur-k8s-lab/3.cityapp-setup/build
- Dockerfile: contain building info
- index.php: detail code of cityapp web application

Running below command to build cityapp image
```
./01.building-cityapp-image.sh
```
Using command ```podman image ls | grep cityapp``` to make sure cityapp image has been build and put at localhost/cityapp

# 3.2. Running cityapp-hardcode
```
./02.running-cityapp-hardcode.sh
```
Using browser and access to ```http://<VM-IP>:30080``` to open cityapp-hardcode webapp for the result

![cityapp](./images/09.cityapp-hardcode.png)

Using k8s dashboard GUI and select cityapp namespace to see more detail on cityapp-hardcode pod. This application is being run with database credentials from environment parameters.

![cityapp](./images/10.cityapp-hardcode-pod.png)

# 3.3. Running cityapp-conjurtok8sfile
Application cityapp-conjurtok8sfile is configured with sidecar container (secrets-provider-for-k8s) which is run in the same pod with cityapp. The sidecar will connect to conjur follower pod, using jwt authentication method and check for database credentials. Information will then be written into ```/conjur/secret``` folder and linked to cityapp's ```/conjur``` folder using shared volume. The architecture of this method is described at below Idira document link.

[Idira Secret Provider: Push to File mode](https://docs.cyberark.com/Product-Doc/OnlineHelp/AAM-DAP/Latest/en/Content/Integrations/k8s-ocp/cjr-k8s-secrets-provider-ic-p2f.htm?TocPath=Integrations%7COpenShift%2FKubernetes%7CSet%20up%20applications%7CSecrets%20Provider%20for%20Kubernetes%7CInit%20container%7C_____2 "Push to file")

![push2file](https://github.com/cyberark/secrets-provider-for-k8s/raw/main/assets/how-push-to-file-works.png)

To deploy conjurtok8sfile application, run:
```
./03.running-cityapp-conjurtok8sfile.sh
```

Going to k8s dashboard GUI, select cityapp namespace and open cityapp-conjurtok8sfile 's sidecar container log, the detail of authentication result will be shown as below
```
INFO:  2022/11/20 17:29:18.217628 main.go:62: CSPFK008I CyberArk Secrets Provider for Kubernetes v1.4.4-5f8218a starting up
INFO:  2022/11/20 17:29:18.219453 main.go:226: CSPFK014I Authenticator setting DEBUG provided by environment
INFO:  2022/11/20 17:29:18.219480 configuration_factory.go:82: CAKC070 Chosen "authn-jwt" configuration
INFO:  2022/11/20 17:29:18.219521 main.go:217: CSPFK014I Authenticator setting CONTAINER_MODE provided by annotation conjur.org/container-mode
INFO:  2022/11/20 17:29:18.219529 main.go:226: CSPFK014I Authenticator setting DEBUG provided by environment
INFO:  2022/11/20 17:29:18.219535 main.go:217: CSPFK014I Authenticator setting JWT_TOKEN_PATH provided by annotation conjur.org/jwt-token-path
INFO:  2022/11/20 17:29:18.219542 main.go:226: CSPFK014I Authenticator setting CONJUR_AUTHN_LOGIN provided by environment
INFO:  2022/11/20 17:29:18.219587 authenticator_factory.go:34: CAKC075 Chosen "authn-jwt" flow
INFO:  2022/11/20 17:29:18.327256 authenticator.go:63: CAKC066 Performing authn-jwt
INFO:  2022/11/20 17:29:18.499870 authenticator.go:83: CAKC035 Successfully authenticated
INFO:  2022/11/20 17:29:18.499908 conjur_secrets_retriever.go:74: CSPFK003I Retrieving following secrets from DAP/Conjur: [test/host1/host test/host1/user test/host1/pass]
INFO:  2022/11/20 17:29:18.499934 conjur_client.go:21: CSPFK002I Creating DAP/Conjur client
INFO:  2022/11/20 17:29:18.560742 provide_conjur_secrets.go:126: CSPFK015I DAP/Conjur Secrets pushed to shared volume successfully
```

Using browser and go to ```http://<VM-IP>:30081``` to see the result
![cityapp](./images/11.cityapp-conjurtok8sfile.png)

# 3.4. Running cityapp-conjurtok8ssecret
Application cityapp-conjurtok8ssecret is configured with a secrets-provider-for-k8s container in the same pod as cityapp (a sidecar - `conjur.org/container-mode: sidecar` plus `CONTAINER_MODE: init` on the provider container is the officially documented combination for this mode, see Idira's own Sidecar-tab example at the link below - `CONTAINER_MODE: init` here does not mean "runs once and exits"). It connects to the conjur follower pod using the jwt authentication method, fetches the database credentials, and keeps pushing them into kubernetes secret name ```db-creds``` (configured in the application's namespace, needs RBAC configuration to allow the update method on k8s secrets) on the interval set by ```conjur.org/secrets-refresh-interval```. When cityapp's main container running, it will access to secret content via files in /etc/secret-volume which is the shared volume that is linked to secret ```db-creds``` - since that's a K8s Secret **volume mount**, its content stays in sync automatically as the sidecar keeps updating ```db-creds```. The architecture of this method is described at below Idira document link.

[Idira Secret Provider: Kubernetes Secret mode](https://docs.cyberark.com/Product-Doc/OnlineHelp/AAM-DAP/Latest/en/Content/Integrations/k8s-ocp/cjr-k8s-secrets-provider-ic.htm?tocpath=Integrations%7COpenShift%252FKubernetes%7CApp%20owner%253A%20Set%20up%20workloads%20in%20Kubernetes%7CSet%20up%20workloads%20(cert-based%20authn)%7CSecrets%20Provider%20for%20Kubernetes%7CInit%20container%252FSidecar%7C_____1 "Push to secret")

![push2k8s](./images/cj-push2secrets.png)

```
./04.running-cityapp-conjurtok8ssecret.sh
```

In k8s dashboard's GUI, checking for the conjurtok8ssecret container's log in the pod, the detail of conjur jwt authentication and secret pushing will be shown as below
```
INFO:  2022/11/20 17:51:05.371062 main.go:62: CSPFK008I CyberArk Secrets Provider for Kubernetes v1.4.4-5f8218a starting up
INFO:  2022/11/20 17:51:05.371238 main.go:226: CSPFK014I Authenticator setting DEBUG provided by environment
INFO:  2022/11/20 17:51:05.371259 configuration_factory.go:82: CAKC070 Chosen "authn-jwt" configuration
INFO:  2022/11/20 17:51:05.371295 main.go:217: CSPFK014I Authenticator setting CONTAINER_MODE provided by annotation conjur.org/container-mode
INFO:  2022/11/20 17:51:05.371305 main.go:226: CSPFK014I Authenticator setting DEBUG provided by environment
INFO:  2022/11/20 17:51:05.371316 main.go:226: CSPFK014I Authenticator setting JWT_TOKEN_PATH provided by environment
INFO:  2022/11/20 17:51:05.371325 main.go:226: CSPFK014I Authenticator setting CONJUR_AUTHN_LOGIN provided by environment
INFO:  2022/11/20 17:51:05.376197 authenticator_factory.go:34: CAKC075 Chosen "authn-jwt" flow
INFO:  2022/11/20 17:51:05.420251 k8s_secrets_client.go:56: CSPFK004I Creating Kubernetes client
INFO:  2022/11/20 17:51:05.420739 k8s_secrets_client.go:21: CSPFK005I Retrieving Kubernetes secret 'db-creds' from namespace 'cityapp'
INFO:  2022/11/20 17:51:05.438234 authenticator.go:63: CAKC066 Performing authn-jwt
INFO:  2022/11/20 17:51:05.550677 authenticator.go:83: CAKC035 Successfully authenticated
INFO:  2022/11/20 17:51:05.550718 conjur_secrets_retriever.go:74: CSPFK003I Retrieving following secrets from DAP/Conjur: [test/host1/host test/host1/user test/host1/pass]
INFO:  2022/11/20 17:51:05.550726 conjur_client.go:21: CSPFK002I Creating DAP/Conjur client
INFO:  2022/11/20 17:51:05.682514 k8s_secrets_client.go:56: CSPFK004I Creating Kubernetes client
INFO:  2022/11/20 17:51:05.683098 k8s_secrets_client.go:40: CSPFK006I Updating Kubernetes secret 'db-creds' in namespace 'cityapp'
INFO:  2022/11/20 17:51:05.690806 provide_conjur_secrets.go:184: CSPFK009I DAP/Conjur Secrets updated in Kubernetes successfully
```

Using browser and go to ```http://<VM-IP>:30082``` to see the result
![cityapp](./images/12.cityapp-conjurtok8ssecret.png)

# 3.5. Building and running cityapp-springboot
This is a Java/Spring Boot rewrite of cityapp, built from ```4.cityapp-springboot/build/``` (a Maven project). Its business logic and web page are the same as the PHP cityapp, but it can be deployed two different ways that are worth trying separately.

## Step3.5.1: Building the image
```
cd /opt/lab/conjur-k8s-lab/4.cityapp-springboot
vi 00.config.sh
```
Set ```READY=true```, then build the image:
```
./41.building-cityapp-image.sh
```
This installs Java 17, runs the Maven build, and tags the result ```cityapp-springboot```. If the build tools aren't available it automatically falls back to pulling a prebuilt image instead, so this step always produces something usable either way.

## Step3.5.2: Deploying cityapp-springboot - two options
Both options deploy the same image built above, but as separate Deployments/Services with their own NodePort, so you can run both side by side and compare them directly.

**Option A - secrets-provider-for-k8s sidecar** (same mechanism as Step 3.3/3.4 above, just with the Java app instead of PHP):
```
cd /opt/lab/conjur-k8s-lab/3.cityapp-setup
./06.running-cityapp-springboot.sh
```
Using browser and go to ```http://<VM-IP>:30083``` to see the result.

**Option B - native Secrets Manager Spring Boot SDK** (the app itself calls the Secrets Manager API directly at startup via `ConjurSpringDbConfig.java` - no sidecar, no secrets-provider-for-k8s):
```
cd /opt/lab/conjur-k8s-lab/4.cityapp-springboot
./42.running-cityapp-springboot.sh
```
Using browser and go to ```http://<VM-IP>:30088``` to see the result.

# PART III-A: TESTING EXTERNAL SECRETS OPERATOR (ESO)
Unlike the sidecar-based variants above, this section shows secrets flowing into Kubernetes from *outside* the pod entirely: the External Secrets Operator (ESO) authenticates to Secrets Manager on its own and syncs a value into a native Kubernetes Secret, and the app that consumes it needs no Secrets Manager awareness at all - no sidecar, no ServiceAccount, no JWT token.

## Step3A.1: Reviewing 00.config.sh
```
cd /opt/lab/conjur-k8s-lab/5.conjur-eso
vi 00.config.sh
```
Set ```READY=true``` to continue - this folder reuses the same ```2.conjur-setup/00.config.sh``` values (domain, DB credentials, JWT audience).

## Step3A.2: Installing ESO
```
./00.installing-eso-helm.sh
```
Installs Helm if missing, then the ```external-secrets``` Helm chart into its own namespace.

## Step3A.3: Loading the ESO Secrets Manager policy
```
./01.adding-conjur-eso-policy.sh
```
Grants the ESO service account JWT authentication access, and sets a second demo variable set (```test/host2/host```, ```test/host2/user```, ```test/host2/pass```) to the same working database credentials used elsewhere in the lab.

## Step3A.4: Creating the Secrets Manager SecretStore
```
./02.creating-ext-secret-store.sh
```
Registers Secrets Manager as an ESO ```SecretStore``` using JWT auth against the Secrets Manager follower.

## Step3A.5: Creating the ExternalSecret
```
./03.creating-eso-secret.sh
```
Tells ESO to sync ```test/host2/*``` into a native Kubernetes Secret named ```conjur-secret```.

## Step3A.6: Verifying the synced secret
```
./04.getting-eso-secret.sh
```
Prints the ```ExternalSecret``` sync status and the decoded contents of ```conjur-secret```.

## Step3A.7: Running cityapp-eso
```
./05.running-cityapp-eso.sh
```
Deploys the same ```cityapp``` PHP image built in Part III, unmodified, mounting ```conjur-secret``` directly at ```/etc/secret-volume```. Using browser and go to ```http://<VM-IP>:30084``` to see the result - the page will show the secret source as "K8S SECRETS", same as ```cityapp-conjurtok8ssecret```, but this Secret was populated by ESO rather than a sidecar.

# PART III-B: TESTING THE CONJUR CSI PROVIDER
A third way to deliver secrets into a pod: the Kubernetes Secrets Store CSI Driver mounts them directly as a volume, resolved live by Idira's Secrets Manager CSI provider at mount time. The provider authenticates using an explicit identity rather than auto-resolving one from JWT claims, so - like ESO - the app itself needs no ServiceAccount token projection, sidecar, or Secrets Manager awareness.

## Step3B.1: Reviewing 00.config.sh
```
cd /opt/lab/conjur-k8s-lab/6.conjur-csi
vi 00.config.sh
```
Set ```READY=true``` to continue. This folder reuses ```2.conjur-setup/00.config.sh``` and additionally defines ```CSI_JWT_AUDIENCE``` (default ```conjur```) - the audience the CSI driver requests tokens with, distinct from the lab's shared ```JWT_AUDIENCE```.

## Step3B.2: Installing the Secrets Store CSI Driver
```
./00.installing-csi-helm.sh
```
Installs Helm if missing, then the ```secrets-store-csi-driver``` chart into ```kube-system```.

## Step3B.3: Loading the CSI Secrets Manager policy
```
./01.adding-conjur-csi-jwt-policy.sh
```
Defines a second, CSI-specific JWT authenticator (```authn-jwt/k8s-csi```, distinct from the ```authn-jwt/k8s``` used everywhere else) and its host identity.

## Step3B.4: Redeploying the Secrets Manager follower with CSI support
```
./02.redeploy-follower-with-k8s-csi.sh
```
Replaces the follower deployed in Part II with one that has both ```authn-jwt/k8s``` and ```authn-jwt/k8s-csi``` enabled.

## Step3B.5: Installing the Secrets Manager CSI provider
```
./03.installing-conjur-csi-provider.sh
```
Installs Idira's ```conjur-k8s-csi-provider``` Helm chart into ```kube-system```.

## Step3B.6: Creating the SecretProviderClass
```
./04.creating-secret-provider-class.sh
```
Creates a ```SecretProviderClass``` named ```conjur-credentials``` in the ```cityapp``` namespace, pointing at the Conjur follower.

## Step3B.7: Running cityapp-csi
```
./05.running-cityapp-csi-test.sh
```
Deploys ```cityapp-csi```, mounting secrets via the CSI volume at ```/etc/secret-volume``` (resolved from ```test/host1/*```, the same working demo credentials used since Part II). Using browser and go to ```http://<VM-IP>:30086``` to see the result.

# PART IV: FINAL TESTING
Run ```2.conjur-setup/13.rotating-db-password.sh``` (equivalent to ```2.conjur-setup/13.rotating-db-password.sh host1```). It changes the actual MySQL password for the demo DB user and updates ```test/host1/pass``` in Secrets Manager to match - deliberately leaving ```test/host2/pass``` untouched. Refresh each cityapp webpage after ~30-60 seconds to see how each method actually handles a rotated credential:
- ```cityapp-conjurtok8sfile``` (30081) and ```cityapp-conjurtok8ssecret``` (30082) pick it up live, no redeploy needed - the secrets-provider sidecar keeps refreshing the file/Secret it writes to, and both apps read that shared volume fresh on every page load.
- ```cityapp-springboot-sidecar``` (30083), ```cityapp-springboot-native``` (30088) and ```cityapp-csi``` (30086) need a redeploy: springboot-sidecar's DB password is wired up as a `secretKeyRef` env var, which Kubernetes captures once at pod start and never live-updates even though the same sidecar keeps the underlying Secret current; springboot-native fetches once via the Secrets Manager SDK at startup with no refresh loop; and this lab's CSI driver install doesn't enable secret rotation, so the mounted volume is fetched once too.
- ```cityapp-hardcode``` (30080) and ```cityapp-eso``` (30084) are left showing a DB connection error: hardcode because it never talks to Secrets Manager at all, eso because it reads ```test/host2/*```, which the script leaves alone on purpose. This is the actual payoff of the whole lab - a live side-by-side of what a credential rotation costs you with each method.

To bring ```cityapp-eso``` back afterward without doing a fresh rotation, run ```2.conjur-setup/13.rotating-db-password.sh host2``` - it copies ```test/host1/pass```'s current value into ```test/host2/pass``` (no MySQL change, since the password itself hasn't changed). Or run ```2.conjur-setup/13.rotating-db-password.sh all``` next time to rotate MySQL and update both ```test/host1/pass``` and ```test/host2/pass``` together in one step, leaving only ```cityapp-hardcode``` stuck on the old password.
# --- LAB END ---
