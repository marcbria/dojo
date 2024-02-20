# dojo: Ansible playbooks for a full automated PKP server

| **WARNING:** This is an ongoing project. |
|:--|
| Features could change, be inestable or not even tested. |
| Final version is planned to be released at the end of March. |

TL;DR; The aim of this project is to offer the PKP community a way to host its applications (OJS, OMP...) on-premises, in a simple, standardised and resilient way.

To do this, the project offer a set of tools to convert a brand new Debian (or another DebianA based distro), to and dedicated server able to host, maintain and upgrade any PKP application and also to include all the additional tools to manage the service.

Project is created with the following pillars in mind:
- **Standarization:** All decisions regarding to tecnologies and development are taken thinking in stadards first. When there is no standard to apply, the decisions are homogeneous.
- **Resilence**: Based on gitOps aproach, the infrastrucutre is build over declarative descriptions, stored under control version system and full-automatized.
- **Simplicity**: Main design principle is KISS. Once a feature is stabilized, will be simplified with a set of self-explicative scripts.

All this is build based on two proven and well recognised technologies as:
- **Ansible:** For the installation and maintenance of the service, which makes it easy to understand and portable.
- **Docker:** To keep applications issolated and make them easy to upgrade and also with docker-compose to help with the deployments.

The full project and the scripts are divided in 3 parts:
- **Infrastructure:** To install all the underlaying software required to support the service (ie: docker...).
- **Service:** To install all the containers needed to maintain the service (ie: reverse proxy...).
- **Dojo:** To install and maintain the PKP apps and the helpers (ie: journals and books).

To "Keep It Simple Stupid", and to avoid errors during calls, I recommend to use the set of justfile scripts (see [just](https://github.com/casey/just#packages)) provided, but is also possible to run the ansible playbooks directly if you like.

As far as code is quite self-explanatory, the documentation is still rather sparse, but I hope to improve it as time goes by and as questions arise.

New ideas about new needs or improvements and PRs are really welcome.

## Structure

The model is based on the usage of containers with images for both, PKP apps and aditional services.
The benefits of this are multiple and will be detailed in future, but in short, this will make the OS simplier and easier to maintain, will reduce the dependences and isolate the web-apps that could be upgrades, monitorized, replaced, moved and backup independently from the rest of the platform.

After running a few installation scripts (and setup some configuration), you will be able to transform a clean Debian (or another Debian based distro), to an specialized server capable of hosting and maintaining and upgrade any PKP application under the following structure:

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

Each box is a container that will be stored in the proper folder acording to it's usage (`service` or `site`) and with the project name (ie: `journalTag` or `proxy`).
Each folder will include, at least, the following structure:

- `docker-compose.yml`: With common description about how to deploy the app.
- `docker-compose.override.yml`: With specific description about how to deploy.
- `.env`: with environment variables required by the containers.
- `volumes`: with the persistent data
        - config: All configuration files (like config.inc.php or certificates)
        - db: The database files.
        - public: Public files.
        - private: Private files.

It's up to you to decide what parts of the project you like to use. For instance, if you have a k8s server, you will probably only need the docker images. If you like to run this in the Cloud, your won't probably need the backup and monitoring part.

Again, it's not mandatory, but this project uses git as a **single source of truth** so all this site structrue will be created (and recreated at any time) based on an ansible-dictionary file ([example for a journal](https://github.com/marcbria/ansible/blob/main/sites/periodicum.yml)) that includes all the required variables and configuration information. Private information will be encrypted and also stored in git with ansible-vault.

## Installation

(This is how it will work, but not full implemented yet)
 
1. In your server, install a clean Debian (or Debian based) distribution and ensure you have ssh access.
2. Clone this repository:
```
$ git clone https://github.com/marcbria/ansible/
```
3. Create your own `inventory/hosts.yml` adding your serverName.
```
$ cd ansible
$ mkdir inventory
$ vim inventory/hosts.yml
# Take a look to [those examples](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/yaml_inventory.html#examples) to create your inventory file.
```

4. Create your diccionary.
5. Create your ansible-volt.
6. Recommended: Install [just](https://github.com/casey/just#packages) versión 1.23 or higher.
7. Use `just` to install the underlaying infrastructure:
```
$ just infra-install ansible
$ REMOTESERVER=serverName
$ just ps $REMOTESERVER                   # Test if you can reach your remote server
$ just infra-dist-upgrade $REMOTESERVER   # Update the server.

$ just infra-install docker
$ just docker-info $REMOTESERVER          # Test docker and docker-compose installations.

$ just infra-install essential
$ just infra-install extra
```
8. Install the reverse proxy:
```
just infra-install proxy
```
9. Create your fist journal:
```
just dojo-create <journalTag>
```

10. Read more about this project and decide if you also like to install:
- Monitoring tool, like uptimekuma.
- Backup apps, like sanoid and duplicati.
- Management apps, like portainer.

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


### Accions

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


#### Why dojo?

Well... long story short? Because technology evolves.

If you like acronyms you can think it cames from "Docker Open Journal Operations" or even from  "DO JOurnals".
If you like oriental philosophy you can think it all it's a metaphor where journal/site is a "dojo" where we teach different martial arts.
If you like the long story, all started sooo long ago when I created an script to manage multiple OJS journals called "[mojo](https://github.com/marcbria/mojo)" (Multiple OJs Operations). Some years after docker apears and I start playing with it creating [docker4ojs](https://github.com/marcbria/docker4ojs) but the initial bash script becomes beast very difficult to manage and test, and I realized first we need good docker images for OJS and OMP... so now that OJS images are stable enough I though was time to move forward and introduce a gitOps approach and ansible to the game... so "dojo" sounds like a romantic name that let me remember the beginings.

At the end, it's just a name that sounds nice.
