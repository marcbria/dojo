# Justfile
# This script is a helper to run all the playbooks of this project.
# You can use the playbooks without just but it will make your life easier.
# If you like to use it, is required to install: https://github.com/casey/just
# Actions are divided in 3 parts:
# - Infrastructure: To setup and maintain your underlaying system (OS + docker).
# - Service: To setup and maintain essential or collateral services.
# - Dojo: To setup and maintain your PKP apps (journals and books).

# General settings
set allow-duplicate-recipes
set positional-arguments

# Default values
host := 'kalimero'

# Imports
import 'scripts/test.just'
import 'scripts/infra.just'
import 'scripts/service.just'
import 'scripts/dojo.just'

default:
    just -l

test:
    just -f "scripts/test.just" -l

infra:
    just -f "scripts/infra.just" -l

service:
    just -f "scripts/service.just" -l

dojo:
    just -f "scripts/dojo.just" -l
