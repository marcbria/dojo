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
import 'justfile.test'
import 'playbooks/infra/justfile'
import 'playbooks/service/justfile'
import 'playbooks/dojo/justfile'

default:
    just -l

test:
    just -f "justfile.test" -l

infra:
    just -f "playbooks/infra/justfile" -l

service:
    just -f "playbooks/service/justfile" -l

dojo:
    just -f "playbooks/dojo/justfile" -l
