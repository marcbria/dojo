# Justfile
# This script is a helper to run all the playbooks of this project.
# You can use the playbooks without just but it will make your life easier.
# If you like to use it, is required to install: https://github.com/casey/just
# Actions are divided in 3 parts:
# - Infrastructure: To setup and maintain your underlaying system (OS + docker).
# - Service: To setup and maintain essential or collateral services.
# - Dojo: To setup and maintain your PKP apps (journals and books).

# General
generalHost         := 'kalimero'
# rootPath          := '/home/marc/workspace/dojo'
rootPath            := `pwd`
vaultPath           := './configs/secret.yml'
vaultKey            := './configs/.vault.key'

# Infrastructure vars
justPath            := rootPath / 'playbooks/infra'

# Dojo vars
dojoPath            := rootPath / 'playbooks/dojo'

# Service vars
serviceVaultPath    := './configs/secret.yml'
serviceVaultKey     := './configs/.vault.key'
servicePath         := rootPath / 'playbooks/service'
