# Justfile

# Default values
host := 'kalimero'        # Testing host

# Syntax and examples
info:
    # README
    # To get a list of actions use "just -l"
    @# TBD
    #

    # Playbooks
    @tree playbooks

# Installs ansible and it's roles
ansible-install:
    sudo python3 -m venv venv
    # Activa el entorno virtual (en sistemas Unix/Linux)
    bash -c "source venv/bin/activate"
    sudo apt install ansible git
    ansible-galaxy install -r requirements.yml
    git init && git add . && git commit -m "Initial commit"

ansible-commit:
    git add . && git commit -m "Auto commit..."

# Installs ilatest stable docker & docker-compose and adds marc user to docker group.
docker-install host:
    ansible-playbook -i {{host}}, ./playbooks/0-startup/docker-install.yml -K

# Installs essential tooling (tmux, vim and tldr)
essential-tools host:
    ansible-playbook -i {{host}}, ./playbooks/0-startup/essential-tools.yml -K

# Shows docker and docker-compose version information
docker-info host:
    ansible-playbook -i {{host}}, ./playbooks/1-info/docker-info.yml -K

# Ping all hosts
ping:
    ansible-playbook -i all, ./playbooks/1-info/ping.yml -K

# PS command over host
ps host:
    ansible-playbook -i {{host}}, ./playbooks/1-info/ps.yml -K

# Runs a dist-upgrade, remove unused dependences and reboot.
dist-upgrade host:
    ansible-playbook -i {{host}}, ./playbooks/9-maintenance/dist-upgrade.yml -K

default: info 
