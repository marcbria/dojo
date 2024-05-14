# How to "dojo" (Quickstart)

## Create and install a site 

**Requirements:**

- Sever side: Debian like, docker, docker-compose, Traefik
- Local side: Ansible, just

How to meet the requirements: https://github.com/marcbria/dojo?tab=readme-ov-file#installation

**Instructions:**

```
$ SERVER='adauab';JOURNAL='revista07'     # Set some env-vars to generalize the steps.
$ vim inventory/sites/$JOURNAL            # Create the journal dictionary (stores ALL configs)

$ just dojo-create $JOURNAL $SERVER       # Creates the site based on dictionary.
$ just dojo-manage $JOURNAL $SERVER up    # Raises the site (OJS container and DB).
$ just dojo-run install $JOURNAL $SERVER  # Installs OJS with dictionary data (via curl)
```
