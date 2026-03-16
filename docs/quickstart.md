# Quickstart

A step-by-step guide to get dojo up and running.

## Table of contents

1. [Clone this repository](#1-clone-this-repository)
2. [Install just](#2-install-just)
3. [Create your host inventory](#3-create-your-host-inventory)
4. [Set up the underlying infrastructure](#4-set-up-the-underlying-infrastructure)
5. [Install the reverse proxy](#5-install-the-reverse-proxy)
6. [Create and install a journal](#6-create-and-install-a-journal)
7. [Create and edit your vault](#7-create-and-edit-your-vault)
8. [Install a service](#8-install-a-service)


## The basics

### 1. Clone this repository
```bash
git clone https://github.com/marcbria/dojo/
cd dojo
```

### 2. Install just

Dojo is a collection of Ansible playbooks that can be run directly, but `just`
simplifies all calls into short, self-documenting commands.
```bash
apt install cargo
cargo install just
apt remove cargo     # optional: free up disk space
```

More information: https://github.com/casey/just#packages


### 3. Create your host inventory

Create `inventory/hosts.yml` with your remote server:
```bash
vim inventory/hosts.yml
```

Example:
```yaml
---
all:
  vars:
    ansible_user: youruser
    ansible_port: 22
    ansible_ssh_private_key_file: /home/youruser/.ssh/id_rsa

  children:
    production:
      hosts:
        prod01:
          ansible_host: 192.168.0.1
    testing:
      hosts:
        test01:
          ansible_host: 192.168.0.2
        localhost:
          ansible_connection: local
```

See the [Ansible inventory docs](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/yaml_inventory.html#examples) for more examples.


### 4. Set up the underlying infrastructure
```bash
just infra-install-ansible                      # Install Ansible on local machine.

REMOTESERVER=<yourServer>
just infra-run info-ps $REMOTESERVER -K         # Verify remote server is reachable.
just infra-dist-upgrade $REMOTESERVER           # Update the server packages.

just infra-run install-basic $REMOTESERVER -K   # Install essential tooling (curl, rsync…).
just infra-run install-docker $REMOTESERVER -K  # Install Docker and Docker Compose.
just infra-run info-docker $REMOTESERVER -K     # Verify Docker installation.

just infra-run create-user $REMOTESERVER        # Create docker user/group and base folders.
```


### 5. Install the reverse proxy

Edit the Traefik inventory with your domain, email and credentials:
```bash
vim inventory/services/traefik.yml
```

Key fields to set:
```yaml
dojo:
  domain: "proxy.example.org"        # Dashboard domain.

app:
  certificate:
    email: "admin@example.org"       # Used for Let's Encrypt.
    staging: false                   # Set true during testing to avoid LE rate limits.
  credentials:
    username: "admin"
    password: "$$apr1$$..."          # Generate with: echo $(htpasswd -nb user pwd)
```

Then deploy:
```bash
just service-create traefik $REMOTESERVER
```

> **Note:** Port 80 must be open on the server for the Let's Encrypt HTTP challenge.
> Use `staging: true` during initial setup to avoid hitting rate limits.


## The actions

### 6. Create and install a journal

**Requirements:**
- Server: Debian-based OS, Docker, Docker Compose, Traefik running.
- Local: Ansible, just.

**Steps:**
```bash
SERVER=myserver
JOURNAL=myjournal                               # Must be lowercase.

# Create the journal dictionary:
cp inventory/sites/serverprod/demo.yml inventory/sites/serverprod/$JOURNAL.yml
vim inventory/sites/serverprod/$JOURNAL.yml

# Build, start and install:
just dojo-create $JOURNAL $SERVER               # Creates folders and config files.
just dojo-manage $JOURNAL $SERVER up            # Starts OJS and DB containers.
just dojo-run install $JOURNAL $SERVER          # Runs OJS web installer via HTTP.
```

#### Journal dictionary example
```yaml
dojo:
  id: myjournal                         # Must be lowercase.
  tool: ojs
  version: "3_3_0-17"
  versionFamily: "3_3_0"
  domain: "myjournal.example.org"
  type: domain-noslug                   # Options: domain, domain-noslug, folder, folder-noslug

images:
  db:  "mariadb:11.3"
  app: "pkpofficial/ojs:3_3_0-17"

proxy:
  domains: "`myjournal.example.org`"

database:
  tool: mariadb
  version: "11.3"
  host: "db"
  user: "ojs"
  pass: "vaultPwd"                      # Replaced by vault at runtime.
  name: "ojs"
  driver: "mysqli"

pkp:
  admin:
    mail: "admin@example.org"
    pass: "vaultPwd"                    # Replaced by vault at runtime.
  general:
    installed: "Off"
    base_url: "https://myjournal.example.org"
    base_url_index: "https://myjournal.example.org/index"
    base_url_journal: "https://myjournal.example.org"
    scheduled_tasks: "On"
    restful_urls: "On"
    enable_beacon: "Off"
  email:
    smtp: "Off"
    smtp_auth: "tls"
    dmarc_compliant_from_displayname: "%n via My Journal"
  oai:
    id: myjournal.example.org
  database:
    host:     "db"
    driver:   "mysqli"
    username: "ojs"
    password: "vaultPwd"                # Replaced by vault at runtime.
```

See `docs/installations.md` for details on each URL type.


### 7. Create and edit your vault

The vault stores all sensitive values (passwords, tokens). It is encrypted with
ansible-vault and safe to commit to git.
```bash
just dojo-vault create                  # Creates configs/secret.yml + configs/.vault.key
just dojo-vault edit                    # Edit the vault contents
```

Example vault structure:
```yaml
# Keep this minimal — only secrets, no configuration.

vault:
  general:
    database:
      MYSQL_ROOT_PASSWORD: "yourRootPwd"
      MYSQL_PASSWORD: "yourPwd"
    pkp:
      OJS_ADMIN_PASSWORD: "yourAdminPwd"
      OJS_DB_PASSWORD: "yourPwd"        # Must match MYSQL_PASSWORD.
      SMTP_PASS: "yourSmtpPwd"

  services:
    traefik:
      appPass: "yourTraefikPwd"
```


### 8. Install a service

Services are additional containers managed alongside Traefik (monitor, analytics…).
The workflow is identical to Traefik:
```bash
# 1. Create or edit the service inventory:
vim inventory/services/<serviceName>.yml

# 2. Deploy:
just service-create <serviceName> $SERVER

# 3. Manage:
just service-manage <serviceName> $SERVER up
just service-manage <serviceName> $SERVER restart
just service-manage <serviceName> $SERVER stop
```

Available services: `traefik`, `uptimekuma`, `plausible`, `drupal`, `survey`.

