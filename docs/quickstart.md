# How to "dojo" (a Quickstart)

List of howto actions you can do with `dojo`:

[The basics](#the-basics)
1. [Clone this repository](#clone-this-repository)
2. [Install "just" helper](#install-just-helper)
3. [Create your inventory of servers](#create-your-inventory-of-servers)
4. [Set up your underlying infrastructure](#set-up-your-underlying-infrastructure)
5. [Install the reverse proxy](#install-the-reverse-proxy) (TBD)

[The actions](#the-actions)

6. [Create and install a Journal](#create-and-install-a-journal)
7. [Create and edit your Vault](#create-and-edit-your-vault)


## The basics

### Clone this repository

```
$ git clone https://github.com/marcbria/dojo/
```


### Install "just" helper

Dojo is a list of ansible playbooks so you can run it with ansible alone but in this documentation we asume you installed `just` that is a "kind-of" make language variant that helps to simplify the scripts calls.

To install just, easiest way is with `cargo`:

```
$ apt install cargo
$ cargo install just
```

More information: https://github.com/casey/just#packages


### Create your inventory of servers

Create your own `inventory/hosts.yml` adding your remoteServer name.

```
$ cd dojo
$ mkdir inventory
$ vim inventory/hosts.yml
```

An example of inventory:

```
---
all:
  vars:
    ansible_user: marc
    ansible_port: 22
    ansible_ssh_private_key_file: /home/marc/.ssh/id_rsa

  children:
    production:
      hosts: 
        prod01:
          ansible_host: 192.168.0.1
          #ansible_python_interpreter: /usr/bin/python3
        prod02:
          ansible_host: 192.168.0.2 
    testing:
      hosts:
        test01:
          ansible_host: 192.168.0.1
        localhost:
          ansible_connection: local
```

Take a look to [those examples](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/yaml_inventory.html#examples) to create your own inventory file.


### Set up your underlying infrastructure

With `just` you can install ALL the underlaying infrastructure as follows:

```
$ just infra-install-ansible                      # Install ansible in local machine.

$ REMOTESERVER=<remoteServer>                     # Set env-vars to make it more readable
$ just infra-run info-ps $REMOTESERVER -K         # Test if remote server is reachable.
$ just infra-dist-upgrade $REMOTESERVER           # Update the server.

$ just infra-run install-basic $REMOTESERVER -K   # Essential tooling (curl,rsync,pip...)

$ just infra-run install-docker $REMOTESERVER -K  # Install docker & docker-compose.
$ just infra-run info-docker $REMOTESERVER -K     # Test docker and docker-compose.

$ just infra-run create-user $REMOTESERVER        # Create docker user/group and folders.
```

### Install the reverse proxy

TBD


## The actions

### Create and install a Journal 

**Requirements:**

- Sever side: Debian like, docker, docker-compose, Traefik
- Local side: Ansible, just

How to meet the requirements: https://github.com/marcbria/dojo?tab=readme-ov-file#installation

**Instructions:**

```
$ SERVER='adauab';JOURNAL='journalname'   # Set some env-vars to generalize the steps.
$ vim inventory/sites/$JOURNAL            # Create the journal dictionary (stores ALL configs)

$ just dojo-create $JOURNAL $SERVER       # Creates the site based on dictionary.
$ just dojo-manage $JOURNAL $SERVER up    # Raises the site (OJS container and DB).
$ just dojo-run install $JOURNAL $SERVER  # Installs OJS with dictionary data (via curl)
```

### Create the journal dictionary 

Create a file in inventory/sites/journalname.yml

Example of content:

```
dojo:
  id: journalname                       # This MUST be lowercase.
  tool: ojs
  version: "stable-3_3_0"
  versionFamily: "3_3_0"
  domain: "foo.net"
  type: domain

proxy:
  domains: "`foo.net`,`journalname`"

database:
  tool: mariadb
  version: "10.2"
  host: db
  user: ojs
  name: ojs
  driver: mysqli

images:
  db:  "{{ database.tool }}:{{ database.version }}"
  app: "pkpofficial/{{ dojo.tool }}:{{ dojo.version }}"

pkp:
  general:
    installed: Off
    base_url: "https://{{ dojo.domain }}"
    scheduled_tasks: On
  database:
    host:     "{{ database.host }}"
    username: "{{ database.user }}"
    driver:   "{{ database.driver }}"
```

### Create and edit your Vault

```
$ just dojo-vault create                  # Creates a vault at "./configs/secret.yml"
                                          # protected by key at "./configs/.vault.key"
$ just dojo-vault edit                    # Edits the vault
```

**Example of vault:**

```
# Vault for sensitive variables.
# Recommendation: Keep this to minimum.

vault:
  general:
    database:
      # MySQL
      MYSQL_ROOT_PASSWORD: "yourRootPwd"      # MySQL Root Pass
      MYSQL_PASSWORD: "yourPwd"               # MySQL DB Pass
    pkp:
      # OJS
      OJS_ADMIN_PASSWORD: "yourAdminPwd"      # OJS ADMIN Pass
      OJS_DB_PASSWORD: "yourPwd"              # OJS BD Pass (same as MYSQL_PASSWORD)
      SMTP_PASS: "yourSmtpPwd"                # SMTP Pass

  services:
    # Traefik
    traefik:
      appPass: "yourTraefikPwd"               # Traefik's pass.

  test:
    fooPass: "AllIsFine"
```


### Install a service

(TBD)
