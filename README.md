# dojo: Ansible playbooks for a full automated PKP server

| **WARNING:** This is an ongoing project. |
|:--|
| Features could change, be unstable or not even tested. |
| Final version is planned to be released at the end of March. |

TL;DR; The aim of this project is to offer the PKP community a way to host its applications (OJS, OMP...) on-premises, in a simple, standardised and resilient way.

To do this, the project offer a set of tools to convert a brand new Debian (or any other Debian based distribution), to and dedicated server able to host, maintain and upgrade any PKP application and also to include all the additional tools to manage the service.

Project is created with the following pillars in mind:
- **Standarization:** All decisions regarding to technologies and development are taken thinking in stadards first. When there is no standards to apply, the decisions are homogeneous.
- **Resilience**: Based on gitOps aproach, the infrastructure is build over declarative descriptions, stored under control version system and full-automatized.
- **Simplicity**: Main design principle is KISS. Once a feature is stabilized, will be simplified with a set of self-explanatory scripts.

All this is build based on two proven and well recognised technologies as:
- **Ansible:** For the installation and maintenance of the service, which makes it easy to understand and portable.
- **Docker:** To keep applications isolated and make them easy to upgrade and also with docker-compose to help with the deployments.

The full project and the scripts are divided in 3 parts:
- **Infrastructure:** To install all the underlaying software required to support the service (ie: docker...).
- **Service:** To install all the containers needed to maintain the service (ie: reverse proxy...).
- **Dojo:** To install and maintain the PKP apps and the helpers (ie: journals and books).

To "Keep It Simple Stupid", and to avoid errors during calls, I recommend to use the set of justfile scripts (see [just](https://github.com/casey/just#packages)) provided, but is also possible to run the ansible playbooks directly if you like.

As far as code is quite self-explanatory, the documentation is still rather sparse, but I hope to improve it as time goes by and as questions arise.

New ideas about new needs or improvements and PRs are really welcome.

## Structure

The model is based on the usage of containers with images for both, PKP apps and aditional services.

The benefits of this are multiple and will be detailed in future, but in short, this will make the OS simpler and easier to maintain, will reduce the dependencies and isolate the web-apps that could be upgrades, monitored, replaced, moved and backup independently from the rest of the platform.

All the process of installation and management is automatized via ansible playbooks. It means, after some basic configuration you will only need to run a few installation scripts to transform a clean Debian (or another Debian based distro) into a server specialized in hosting and maintaining any PKP application under the following logic structure:

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

Each box is a container that will be stored in the proper folder according to it's usage (`service` or `site`) and with the project name (ie: `journalTag` or `proxy`).

Physically, in your server, this will be stored in two main folders (you can change it in `config/dojo.yml`):

```
[runningFolder] (ie: /home/docker)
├── service
    └── reverseProxy
└── sites
    └── [journalname]
        └── volumes -> /srv/volumes/all/[journalname]

[storageFolder] (ie: /srv)
├── backups
│   └── [journalname]
└── volumes
    ├── all
    │   └── [journalname]
    │       ├── config -> /srv/volumes/files/config/[journalname]
    │       ├── db -> /srv/volumes/db/[journalname]
    │       ├── logs -> /srv/volumes/logs/[journalname]
    │       ├── private -> /srv/volumes/files/private/[journalname]
    │       └── public -> /srv/volumes/files/public/[journalname]
    ├── db
    │   └── [journalname]
    ├── files
    │   ├── config
    │   │   └── [journalname]
    │   ├── private
    │   │   └── [journalname]
    │   └── public
    │       └── [journalname]
    └── logs
        └── [journalname]
```

Each site in the `runningFolder` will include, at least, the following structure:

- `docker-compose.yml`: With common description about how to deploy the app.
- `docker-compose.override.yml`: With specific description about how to deploy.
- `.env`: with environment variables required by the containers.
- `volumes`: A symlink to the `storageFolder` with all the persistent data
        - config: All configuration files (like config.inc.php or certificates)
        - db: The database files.
        - public: Public files.
        - private: Private files.

Project is thought to be modular: You can use it as a whole, or use only the parts that are useful to you.
For instance, you can call playbooks directly (without justfile helpers), or use it all to set up your
infrastruture and sites, and then forget about the project and manage it manually without ansible.

Again, it's not mandatory, but this project uses git as a **single source of truth** so all this site structure will be created (and recreated at any time) based on an ansible-dictionary file ([example for a journal](https://github.com/marcbria/ansible/blob/main/sites/periodicum.yml)) that includes all the required variables and configuration information. Private information will be encrypted and also stored in git with ansible-vault.


## Installation

(This is how it will work, but not full implemented yet)

#### Ingredients

- Sever: A clean Debian (or Debian based) distribution (ensure you have SSH access).
- Local: Ansible installed (use `just infra-install-ansible` if you like).

#### Recipe

Instructions are detailed in the "[Installation Manual](#InstallationManual)" but, from a bird's eye view, the process is divided in 3 parts:

** Basic requirements: **
1. Clone this repository.
2. Create your own `inventory/hosts.yml` adding your remoteServer name.
3. Recommended: Install [just](https://github.com/casey/just#packages) version 1.23 or higher.

** Set up your underlying infrastructure: **
4. Use `just` to install the underlaying infrastructure.
5. Install the reverse proxy.

** Create journal: **
6. Create your first journal's dictionary.
7. Create your ansible-vault add edit your journal's passwd.
8. Build your fist journal.
9. Visit your new journal in your browser and finish your installation.

** Extend your service: **
10. Read more about this project and decide what other tools you also like to install.

### Tooling

| Function       | Tools                                   | Type        | Infrastructure  |
|:---------------|:----------------------------------------|:------------|:----------------|
| Infrastructure | git, ansible, docker, docker-compose    | Host        | Required        |
| Reverse-proxy  | Traefik                                 | Container   | Required        |
| Journals       | OJS                                     | Container   | Optional        |
| Books          | OMP                                     | Container   | Optional        |
| Monitor        | UptimeKuma                              | Container   | Optional        |
| Backup         | Duplicati                               | Container   | Optional        |
| Statistics     | Plausible				   | Container   | Optional	   |
| Snapshots      | zfs + sanoid                            | Host        | Optional        |
| Extras         | just, tldr, zsh                         | Host        | Optional        |


### Actions

The justfile is divided into the 3 blocks mentioned above:
- Infrastructure
- Service
- Dojo

TBD...

If you prefer to run accions without any helper, or you like to adapt it, review the "[justfile](https://github.com/marcbria/ansible/blob/main/justfile)" and the modules in the '/scripts' folder.


# ToDo

Add more playbooks:
- [ ] To install and configure traefik.
- [ ] To install and configure an OJS journal.
- [ ] To install and configure an OMP monograph.
- [ ] Review infrastructure and extra playbooks.
- [ ] Structure the justfile better.
- [ ] To install and configure monitor tooling.
- [ ] To install and configure backup tool.


## Installation Manual

This section details the installation process. 
Remember this project is still beta and playbooks are self-dependant, so please, follow installation process carefully. 


#### Basic requirements

1. Clone this repository.
```
$ git clone https://github.com/marcbria/dojo/
```

2. Create your own `inventory/hosts.yml` adding your remoteServer name.
```
$ cd dojo
$ mkdir inventory
$ vim inventory/hosts.yml
# Take a look to [those examples](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/yaml_inventory.html#examples) to create your inventory file.
```
3. Recommended: Install [just](https://github.com/casey/just#packages) version 1.23 or higher.


#### Set up your underlying infrastructure

4. Use `just` to install the underlaying infrastructure.
```
$ just infra-install-ansible                    # Install ansible in your local machine.

$ REMOTESERVER=<remoteServer>
$ just infra info ps $REMOTESERVER              # Test if you can reach your remote server.
$ just infra-dist-upgrade $REMOTESERVER         # Update the server.

$ just infra run install-docker $REMOTESERVER   # Install docker & docker-compose.
$ just infra info docker $REMOTESERVER          # Test docker and docker-compose installations.

$ just infra run create-user $REMOTESERVER      # Create docker user and group.
$ just infra run create-folders $REMOTESERVER   # Creates the required folder structure.
```


#### Create journal

5. Install the reverse proxy:
```
just infra run install-proxy $REMOTESERVER
```
6. Create your first journal's dictionary
```
$ JOURNAL=<your_journal>                        # Capital letters not allowed in JOURNAL tag.
$ mv sites/journalname.yml sites/$JOURNAL.yml
$ vim sites/$JOURNAL.yml
```
7. Create your ansible-vault add edit your journal's passwd.
```
$ just dojo-vault create $JOURNAL
$ just dojo-vault create $JOURNAL
```
8. Build your fist journal:
```
just dojo-create $JOURNAL
```
9. Visit your new journal in your browser.


#### Extend your service
10. Read more about this project and decide what other tools you also like to install.

- [ ] Monitoring tool, like uptimekuma.
- [ ] Backup apps, like sanoid and duplicati.
- [ ] Management apps, like portainer.
- [ ] ...

See section "(Tooling)[#Tooling]" for a detailed list.

#### Why dojo?

Well... long story short? Because technology evolves.

If you like acronyms you can think it comes from "Docker Open Journal Operations" or even from  "DO JOurnals".
If you like Oriental philosophy you can think it all it's a metaphor where journal/site is a "dojo" where we teach different martial arts.
If you like the long story, all started sooo long ago when I created an script to manage multiple OJS journals called "[mojo](https://github.com/marcbria/mojo)" (Multiple OJs Operations). Some years after docker apears and I start playing with it creating [docker4ojs](https://github.com/marcbria/docker4ojs) but the initial bash script becomes beast very difficult to manage and test, and I realized first we need good docker images for OJS and OMP... so now that OJS images are stable enough I though was time to move forward and introduce a gitOps approach and ansible to the game... so "dojo" sounds like a romantic name that reminds me of the beginings.

At the end, its just a name that sounds nice.
