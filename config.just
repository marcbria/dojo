# Justfile
# This file include all config variables required to run your justfiles.
# You will only need to change "remoteHost", as your default testing server
# but you can also change the rest if you like.

# General
remoteHost          := 'testing'            # Set your default remote server.
rootPath            := `pwd`
vaultPath           := './configs/secret.yml'
vaultKey            := './configs/.vault.key'

# Infrastructure vars
infraPath           := rootPath / 'playbooks/infra'

# Dojo vars
dojoPath            := rootPath / 'playbooks/dojo'

# Service vars
servicePath         := rootPath / 'playbooks/service'