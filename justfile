# Justfile
# This script is a helper to run all the playbooks of this project.
# You can use the playbooks without just but it will make your life easier.
# If you like to use it, is required to install: https://github.com/casey/just
# Actions are divided in 3 parts:
# - Infrastructure: To setup and maintain your underlaying system (OS + docker).
# - Service: To setup and maintain essential or collateral services.
# - Dojo: To setup and maintain your PKP apps (journals and books).
# General settings

set allow-duplicate-recipes := true
set positional-arguments    := true

# General variables

import 'config.just'

# Just imports

import 'justfile.test'
import 'justfile.infra'
import 'justfile.service'
import 'justfile.dojo'

# General calls
_default:
    just -l

# test:
#     just -f "justfile.test" -l
# infra:
#     just -f "justfile.infra" -l
# service:
#     just -f "justfile.service" -l
# dojo:
#     just -f "justfile.dojo" -l
