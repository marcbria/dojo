# README for service playbooks

Be sure you ran all the infrastructure scripts first. 
If you didn't, run "$ just infra-help" for more info.

This set of playbooks and helpers will let you to create and manage your service.

To get a list of all possible actions run "$ just service".

Recommended execution order on first installation is:
1. Install the reverse proxy:
$ vim ./inventory/services/traefik.yml          # Edit your proxy's dictionary.
$ just service-create traefik $SERVER           # Install it in your server.


Follow up with `just dojo-help`