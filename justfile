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


# General recipes
_default:
    @ echo "[[ DOJO MAIN ]]"
    @ echo ""
    @ echo "This script let you call 4 types of commands:"
    @ echo "  - infra: To install the required infrastructure (docker and ansible)."
    @ echo "  - service: To install and manage related services (traefik, monitor...)."
    @ echo "  - dojo: To create, upgrade and manage PKP applications (ojs, omp)."
    @ echo "  - test: To test and debug this script."
    @ echo ""
    @ echo "  > Run 'just [type]' for a type-specific list of actions."
    @ echo "  > Run 'just tldr' for a list of common calls."
    @ echo "  > Run 'just readme' for a detailed explanation."


# Shows the list of playbooks.
list $type:
    #!/usr/bin/env sh
    case "$type" in 
        "all") 
            @ just -l; 
            ;; 
        "dojo" | "service" | "infra" | "test") 
            echo "Full list of [$type] playbooks (actions) are:"; 
            ls -1 -R {{ rootPath }}/playbooks/$type/ | grep yml; 
            echo "To get a commented list of actions use 'just $type'"; 
            ;; 
        *) 
            echo "Invalid type: $type";
            echo "Valid values are: dojo, infra, service, all";
            exit 1;
            ;;
    esac

