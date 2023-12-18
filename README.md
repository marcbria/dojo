# Ansible playbooks for Debian

**WARNING:** This is a work in progress project.

Playbooks used to setup a brand new Debian server with:
- ZFS filesystem and tooling (sanoid).
- Docker and docker-compose.
- Traefik as the reverse proxy.
- Extra tooling to make your life easier: git, just, tldr...

You need to create your own inventory/hosts.yml to make it work and then, you can call the initial playbooks with just as follows:

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


# ToDo

Add more playbooks:
- [ ] To install and configure traefik.
- [ ] To install and configure an OJS journal.
