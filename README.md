# Ansible playbooks for Debian

**WARNING:** This is a work in progress project.

Playbooks used to setup a brand new Debian server with:
- ZFS filesystem and tooling (sanoid).
- Docker and docker-compose.
- Traefik as the reverse proxy.
- Extra tooling to make your life easier: git, just, tldr...

First you need to create your own [inventory/hosts.yml](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/yaml_inventory.html#examples).
Then you will need to install ansible and the playbooks.

I setup some "[just](https://github.com/casey/just#packages)" scripts to make this work easier:

```
$ just ansible-install
$ just ps <host>                  # To test if you can reach the server
$ just dist-upgrade <host>        # Update the server.
$ just essential-tools <host>     # Install all essential tooling.
$ just docker-install <host>      # Install docker tools
$ just docker-info <host>         # Check your versions.
```

Other actions are:

    ansible-commit       # Commits everything to the local repository with an "Auto commit..." comment.
    ansible-install      # Installs ansible and it's roles
    default
    dist-upgrade host    # Runs a dist-upgrade, remove unused dependences and reboot.
    docker-info host     # Shows docker and docker-compose version information
    docker-install host  # Installs latest stable docker & docker-compose and adds the runner user to docker group.
    essential-tools host # Installs essential tooling (tmux, vim and tldr)
    info                 # Syntax and examples
    ping                 # Ping all hosts
    ps host              # PS command over host

Review "[justfile](https://github.com/marcbria/ansible/blob/main/justfile)" if you like to run the actions without any helper.

# ToDo

Add more playbooks:
- [ ] To install and configure traefik.
- [ ] To install and configure an OJS journal.
