# dojo: Ansible playbooks for a full automated PKP server

> **Warning:** This is an ongoing project. Features could change, be unstable or not yet tested.

TL;DR: The aim of this project is to offer the PKP community a way to host its applications (OJS, OMP...) on-premises, in a simple, standardised and resilient way.

To do this, the project offers a set of tools to convert a brand new Debian (or any other Debian-based distribution) into a dedicated server able to host, maintain and upgrade any PKP application, including all the additional tools needed to manage the service.

Here you can see a demo showing how a journal is created and installed:

[See video in Vimeo](https://player.vimeo.com/video/946092633)

Project is created with the following pillars in mind:
- **Standardization:** All decisions regarding technologies and development are taken thinking in standards first. When there are no standards to apply, decisions are homogeneous.
- **Resilience:** Based on a GitOps approach, the infrastructure is built over declarative descriptions, stored under version control and fully automated.
- **Simplicity:** Main design principle is KISS. Once a feature is stabilized, it is simplified with a set of self-explanatory scripts.

All this is built on two proven and well-recognised technologies:
- **Ansible:** For the installation and maintenance of the service, making it easy to understand and portable.
- **Docker:** To keep applications isolated and make them easy to upgrade, with docker-compose to help with deployments.

The full project is divided in 3 parts:
- **Infrastructure:** To install all the underlying software required to support the service (e.g. docker).
- **Service:** To install all the containers needed to maintain the service (e.g. reverse proxy).
- **Dojo:** To install and maintain the PKP apps (e.g. journals and books).

To keep it simple and avoid errors, it is recommended to use the justfile scripts (see [just](https://github.com/casey/just#packages)), but it is also possible to run the ansible playbooks directly.

New ideas, improvements and PRs are welcome.


## Structure

The model is based on containers for both PKP apps and additional services.

All installation and management is automated via ansible playbooks. After some basic configuration you only need to run a few scripts to transform a clean Debian into a server specialised in hosting and maintaining PKP applications, under the following structure:
```
                                     +---------+     +-------+
                             +-------|  OJS 1  |-----| DB j1 |
                             |       +---------+     +-------+
                          S  |          ...
                          I  |       +---------+     +-------+
                          T  +-------|  OJS N  |-----| DB jN |
                          E  |       +---------+     +-------+
                          S  |
                             |       +---------+     +-------+
                             +-------|  OMP 1  |-----| DB m1 |
                             |       +---------+     +-------+
                             |          ...
80/443  +---------------+    |       +---------+     +-------+
--------| Reverse Proxy |----+-------|  OMP N  |-----| DB mN |
        +---------------+    |       +---------+     +-------+
                             |
                          S  |       +---------+
                          E  +-------| Monitor |
                          R  |       +---------+
                          V  |       +---------+
                          I  +-------| Backup  |
                          C  |       +---------+
                          E  |          ...
                             |       +---------+
                             +-------| Others  |
                                     +---------+
```

Each box is a container stored in the proper folder according to its usage (`service` or `sites`) and named after the project (e.g. `journalTag` or `proxy`).

Physically, on your server, this is stored in two main folders (configurable in `configs/dojo.yml`):
```
[runningFolder] (e.g. /home/docker)
├── service/
│   └── proxy/
│       ├── docker-compose.yml
│       ├── docker-compose.override.yml
│       ├── .env
│       └── volumes -> /srv/volumes/all/proxy
└── sites/
    └── [journalname]/
        ├── docker-compose.yml
        ├── docker-compose.override.yml
        ├── .env
        └── volumes -> /srv/volumes/all/[journalname]

[storageFolder] (e.g. /srv)
├── backups/
│   └── [journalname]/
└── volumes/
    ├── all/
    │   └── [journalname]/
    │       ├── config  -> /srv/volumes/files/config/[journalname]
    │       ├── db      -> /srv/volumes/db/[journalname]
    │       ├── logs    -> /srv/volumes/logs/[journalname]
    │       ├── private -> /srv/volumes/files/private/[journalname]
    │       └── public  -> /srv/volumes/files/public/[journalname]
    ├── db/
    │   └── [journalname]/
    ├── files/
    │   ├── config/
    │   │   └── [journalname]/
    │   ├── private/
    │   │   └── [journalname]/
    │   └── public/
    │       └── [journalname]/
    └── logs/
        └── [journalname]/
```

Each site in the `runningFolder` contains at least:

- `docker-compose.yml`: Common description of how to deploy the app.
- `docker-compose.override.yml`: Host-specific deployment overrides.
- `.env`: Environment variables required by the containers.
- `volumes/`: Symlink to the `storageFolder` with all persistent data (config, db, public, private).

This project uses git as a **single source of truth**: the entire site structure is created (and can be recreated at any time) from an inventory dictionary file that contains all required variables and configuration. Sensitive data is encrypted with ansible-vault and also stored in git.

Project is modular: use it as a whole, or use only the parts useful to you. You can call playbooks directly without the justfile helpers, or use it all to set up your infrastructure and then manage it manually.


## Installation

> Some parts of this project are still in progress. See the [ToDo](#todo) section for details.

#### Requirements

- **Server:** A clean Debian (or Debian-based) distribution with SSH access.
- **Local:** Ansible installed (use `just infra-install-ansible` if needed).

#### Quick overview

**Basic requirements:**

1. Clone this repository.
2. Create your own `inventory/hosts.yml`.
3. Install [just](https://github.com/casey/just#packages) version 1.23 or higher (recommended).

**Set up the underlying infrastructure:**

4. Install infrastructure on the remote server.
5. Install the reverse proxy.

**Create a journal:**

6. Create your journal's inventory dictionary.
7. Create and edit your ansible-vault.
8. Build your first journal.
9. Visit your new journal in the browser and finish installation.

**Extend your service:**

10. Add optional tooling (monitor, backup, etc.).


### Tooling

| Function       | Tools                                | Type      | Status   |
|:---------------|:-------------------------------------|:----------|:---------|
| Infrastructure | git, ansible, docker, docker-compose | Host      | Required |
| Reverse-proxy  | Traefik                              | Container | Required |
| Journals       | OJS                                  | Container | Optional |
| Books          | OMP                                  | Container | Optional |
| Monitor        | UptimeKuma                           | Container | Optional |
| Backup         | Duplicati                            | Container | Optional |
| Statistics     | Plausible                            | Container | Optional |
| Snapshots      | zfs + sanoid                         | Host      | Optional |
| Extras         | just, tldr, zsh                      | Host      | Optional |


### Actions

The justfile is divided into 4 groups. Run `just <group>` for a list of available actions:

- `just infra` — install and maintain the underlying system (OS + docker).
- `just service` — install and manage services (traefik, monitor…).
- `just dojo` — create and manage PKP applications (journals, books).
- `just test` — test and debug variables and playbooks.


## Inventory

Ansible is data-driven: playbooks work entirely from variables defined in `inventory/`.
A precedence system lets you define shared defaults and override only what changes per host.
```
inventory/
├── hosts.yml
├── services/                          ← vars for services (traefik, monitor…)
│   ├── base-<hostName>.yml            ← Layer 2: defaults shared by all services on a host
│   ├── traefik.yml                    ← Layer 3: traefik config for any host
│   └── <hostName>/
│       └── traefik.yml                ← Layer 4: traefik config specific for this host
└── sites/                             ← vars for PKP apps (journals, books…)
    ├── base-<hostName>.yml            ← Layer 2: defaults shared by all sites on a host
    ├── myJournal.yml                  ← Layer 3: journal config for any host
    └── <hostName>/
        └── myJournal.yml              ← Layer 4: journal config specific for this host
```

This logic is implemented in `playbooks/setAllVars.yml`, which merges the layers in this order (rightmost wins):
```
dojoVars < baseHostVars < genericVars < hostVars = allVars
```

|              | Layer 1            | Layer 2                                           | Layer 3                                  | Layer 4                                             |
|:------------ |:------------------ |:------------------------------------------------- |:---------------------------------------- |:--------------------------------------------------- |
| **priority** | lowest             | middle                                            | high                                     | highest                                             |
| **file**     | `configs/dojo.yml` | `inventory/[services\|sites]/base-<hostName>.yml` | `inventory/[services\|sites]/<name>.yml` | `inventory/[services\|sites]/<hostName>/<name>.yml` |
| **varName**  | `dojoVars`         | `baseHostVars`                                    | `genericVars`                            | `hostVars`                                          |
| **scope**    | global defaults    | all services/sites on a host                      | this service/site on any host            | this service/site on this host only                 |

Layers 2–4 are optional — missing files are silently skipped.
The merge is recursive: nested keys are combined, not replaced wholesale.

> **Tip:** Inspect the final merged variables before running a playbook:
> ```bash
> just test-var-service traefik $SERVER   # for services
> just test-var-site myJournal $SERVER    # for sites
> ```

> **Note:** Any inventory value containing Jinja2 references to other variables
> (e.g. `traefik:{{ dojo.version }}`) must be tagged with `!unsafe` to prevent
> Ansible from evaluating them at load time. They will be resolved later when
> templates are rendered.
> ```yaml
> images:
>   app: !unsafe "traefik:{{ dojo.version }}"
> ```


## Installation Manual

This section details the full installation process step by step.
This project is still in beta — please follow the steps carefully.


#### Basic requirements

1. Clone this repository:
```bash
git clone https://github.com/marcbria/dojo/
cd dojo
```

2. Create your own `inventory/hosts.yml`:
```bash
vim inventory/hosts.yml
# See: https://docs.ansible.com/ansible/latest/collections/ansible/builtin/yaml_inventory.html#examples
```

3. Install [just](https://github.com/casey/just#packages) version 1.23 or higher:
```bash
apt install cargo
cargo install just
```


#### Set up the underlying infrastructure

4. Install the underlying infrastructure on the remote server:
```bash
just infra-install-ansible                      # Install ansible on local machine.

REMOTESERVER=<remoteServer>
just infra-run info-ps $REMOTESERVER -K         # Test remote server is reachable.
just infra-dist-upgrade $REMOTESERVER           # Update the server.

just infra-run install-basic $REMOTESERVER -K   # Install essential tooling (curl, rsync…).
just infra-run install-docker $REMOTESERVER -K  # Install docker & docker-compose.
just infra-run info-docker $REMOTESERVER -K     # Verify docker installation.

just infra-run create-user $REMOTESERVER        # Create docker user/group and folders.
```


#### Install the reverse proxy

5. Edit the Traefik inventory and deploy:
```bash
vim ./inventory/services/traefik.yml            # Set your domain, email and credentials.
just service-create traefik $REMOTESERVER
```


#### Create a journal

6. Create your journal's inventory dictionary:
```bash
JOURNAL=<journalname>                           # Must be lowercase.
cp inventory/sites/serverprod/demo.yml inventory/sites/serverprod/$JOURNAL.yml
vim inventory/sites/serverprod/$JOURNAL.yml
```

7. Create and edit your ansible-vault:
```bash
just dojo-vault create
just dojo-vault edit
```

8. Build your first journal:
```bash
just dojo-create $JOURNAL $SERVER               # Creates folders and config files.
just dojo-manage $JOURNAL $SERVER up            # Starts the OJS and DB containers.
just dojo-run install $JOURNAL $SERVER          # Runs OJS installer via HTTP.
```

9. Visit your new OJS in the browser and complete the journal setup.


#### Extend your service

10. Add optional tooling as needed:

- [ ] Monitoring: uptimekuma.
- [ ] Backup: sanoid, duplicati.
- [ ] Management: portainer.

See the [Tooling](#tooling) table for the full list.


## ToDo

- [x] Install and configure Traefik.
- [x] Structure the justfile.
- [ ] Install and configure an OJS journal (any URL type).
- [ ] Install and configure an OMP monograph.
- [ ] Automate journal setup from dictionary (API or DB injection).
- [ ] Review infrastructure and extra playbooks.
- [ ] Install and configure monitoring tooling.
- [ ] Install and configure backup tooling.


## Why dojo?

Well... long story short? Because technology evolves.

If you like acronyms you can think it comes from "Docker Open Journal Operations" or even from "DO JOurnals". If you like Oriental philosophy you can think it all it's a metaphor where journal/site is a "dojo" where we teach different martial arts. If you like the long story, all started sooo long ago when I created an script to manage multiple OJS journals called ["mojo"](https://github.com/marcbria/mojo) (Multiple OJs Operations). Some years after docker apears and I start playing with it creating [docker4ojs](https://github.com/marcbria/docker4ojs) but the initial bash script becomes beast very difficult to manage and test, and I realized first we need good docker images for OJS and OMP... so now that OJS images are stable enough I though was time to move forward and introduce a gitOps approach and ansible to the game... so "dojo" sounds like a romantic name that reminds me of the beginings.

At the end, it's just a name that sounds nice.
