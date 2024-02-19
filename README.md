# Ansible playbooks to hold all PKP server

**WARNING:** This is a work in progress project.

The aim of this project is to provide a standardised way to install and manage PKP applications.

The project is divided in 3 parts:
- Infrastructure: Installation of all the software needed to support the service (basically: docker).
- Service: Installation of the containers needed to maintain the service (reverse proxy, backup, monitoring...).
- Dojo: Scripts to install and maintain the PKP apps (journals and books).

To make this possible, two proven and recognised technologies have been used:
- Ansible: The installation and maintenance scripts have been developed on top of ansible, which makes them easy to understand and portable.
- Docker: The applications run as docker containers, using docker-compose for deployment.

This is not mandatory, as it is possible to run the ansible playbooks directly, but to avoid having to memorise the calls and to avoid errors, is recommended to use the set of justfile scripts (see [just](https://github.com/casey/just#packages)) is also provided.

So, in short, this project offers all the necessary tools so that, starting from a clean Debian (or another Debian based distro), you end up with a server capable of hosting and maintaining and upgrade any PKP application by creating an standard structure as following:

```
                                    +---------+     +-------+
                            +-------|  OJS 1  |-----| DB j1 |
                            |       +---------+     +-------+
                            |          ...
                            |       +---------+     +-------+
                            +-------|  OJS N  |-----| DB jN |
                            |       +---------+     +-------+
                            |
                            |       +---------+     +-------+
                            +-------|  OMP 1  |-----| DB m1 |
                            |       +---------+     +-------+
                            |          ...
80/443  +--------------+    |       +---------+     +-------+
--------|    Traefik   |----+-------|  OMP N  |-----| DB mN |
        +--------------+    |       +---------+     +-------+
                            |
                            |       +---------+
                            +-------| Monitor |
                            |       +---------+
                            |       +---------+
                            +-------| Backup  |
                            |       +---------+
                            |       +---------+
                            +-------| Others  |
                                    +---------+
```

## Installation

(This is how it will work, but not implemented yet)
 
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
| Snapshots      | zfs + sanoid                            | Host        | Optional        |
| Extras         | just, tldr, zsh                         | Host        | Optional        |


### Accions

The justfile is divided into the 3 blocks mentioned above:


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

