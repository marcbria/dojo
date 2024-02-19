# Justfile

infra-info:
    # README Infrastructure
    # To setup your infrastructure you only need a clean Debian (or Ubuntu) server.
    # This set of playbooks and helpers will help you install and maintain your
    # infrastructure with basic and additional tools (ansible, docker, sanoid...).
    # To get a list of all possible actions use "just -l".
    @# To be extended
    #

    # Playbooks
    @tree playbooks/0-startup
    @tree playbooks/1-info


# Installs ansible and it's roles
infra-install-ansible:
    sudo python3 -m venv venv
    # Activa el entorno virtual (en sistemas Unix/Linux)
    bash -c "source venv/bin/activate"
    sudo apt install ansible git
    ansible-galaxy install -r requirements.yml
    ansible-galaxy collection install community.general
    # Keep changes under version control
    git init && git add . && git commit -m "Initial commit"

# Commits everything to the local repository with an "Auto commit..." comment.
infra-commit:
    git add . && git commit -m "Auto commit..."

# Installs latest stable docker & docker-compose and adds the runner user to docker group.
infra-install-docker host:
    ansible-playbook -i {{host}}, ./playbooks/0-startup/docker-install.yml -K

# Installs essential tooling (tmux, vim and tldr)
infra-install-essential host:
    ansible-playbook -i {{host}}, ./playbooks/0-startup/essential-tools.yml -K

# Shows docker and docker-compose version information
infra-info-docker host:
    ansible-playbook -i {{host}}, ./playbooks/1-info/docker-info.yml -K

# Ping all hosts
infra-ping:
    ansible-playbook -i all, ./playbooks/1-info/ping.yml -K

# PS command over host
infra-ps host:
    ansible-playbook -i {{host}}, ./playbooks/1-info/ps.yml -K

infra-test infra-args:
    echo "TEST: ${infra-args}

# Runs a dist-upgrade, remove unused dependences and reboot.
infra-dist-upgrade host:
    ansible-playbook -i {{host}}, ./playbooks/9-maintenance/dist-upgrade.yml -K
