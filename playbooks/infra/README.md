# README for infrastructure playbooks
To setup your infrastructure you only need a clean Debian (or Ubuntu) server.
This set of playbooks and helpers will help you install and maintain your infrastructure with basic (docker, sanoid) and additional tools.

To get a list of all possible actions run "$ just infra".

Recommended execution order on first installation is:
0. just infra-install-ansible                           # Install ansible in your laptop.
1. just infra-play run dist-upgrade host                # Upgrades the full system.
2. just infra-play run install-zfstools.yml host        # (optional) Only if you use ZFS.
3. just infra-play run install-install-docker.yml host  # THIS IS MANDATORY.
4. just infra-play run install-extras.yml host          # Only if you like the extra tools.
