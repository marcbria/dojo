# README for infrastructure playbooks
To setup your infrastructure you only need a clean Debian (or Ubuntu) server.
This set of playbooks and helpers will help you install and maintain your infrastructure with basic (docker, sanoid) and additional tools.

To get a list of all possible actions run "$ just infra".

Recommended execution order on first installation is:
0. just infra-install-ansible                           # Install ansible in your local machine
T. just infra-info ps $SERVER -K                        # TEST: if you can reach your remote server

1. just infra-dist-upgrade $SERVER                      # Upgrades the full system (-K is implicit)
2. just infra-run install-zfstools.yml $SERVER          # OPTIONAL: Only if you use ZFS
3. just infra-run install-basic $SERVER                 # Essential tooling (curl, rsync, pip...)
4. just infra-run install-docker $SERVER                # Docker and compose are also essential.
5. just infra-run install-extras $SERVER                # OPTIONAL: For extra tools (tmux, vim...)
T. just infra-info docker $SERVER -K                    # TEST: docker and docker-compose.

6. just infra-run create-user $SERVER                   # Create docker user and group and folders.

Follow with `just service-help`
