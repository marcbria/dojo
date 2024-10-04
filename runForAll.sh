#!/bin/bash

# -----------------------------------------------------------------------------
# Script: runForAll.sh
# Author: Marc Bria
# Date: 2024-09-27
# License: GPLv3
# -----------------------------------------------------------------------------
# Description:
# This script executes a specified action for a list of "JOURNALS" on a given 
# "SERVER" and logs the output. It reads the list of journals from a file and 
# for each journal, runs the command:
#     $ just <action> <journal> <server>
# The result is printed to the screen and also logged into a file named:
#     .logs/YYYYMMDD-HHMM-SERVER-filename.log
#
# Parameters:
# 1. SERVER       - The server where the action will be performed.
# 2. ACTION       - The action to execute (e.g., start, stop).
# 3. JOURNAL_FILE - The path and filename containing the list of journals.
#
# Before execution, the script will display the variables and request user 
# confirmation. Logs are saved under a ".logs" directory.
#
# Published under the GNU General Public License v3.
# -----------------------------------------------------------------------------

# Validate that exactly 3 arguments are provided, if not, show usage and exit.
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <SERVER> <ACTION> <JOURNALS_FILE_PATH> [ARGS]"
    echo "Exemple: $0 adauab create-site ./config/pack01.lst"
    exit 1
fi

# Assign input parameters to variables
SERVER=$1         # Server name or address
ACTION=$2         # Action to execute (see playbooks with "just dojo-list")
JOURNAL_FILE=$3   # Third parameter: path to the file containing a list of JOURNALS

shift 3
ARGUMENTS=$@	  # Any other argument (when the ACTION requires it).

# Validate if the JOURNAL file exists and is readable
if [ ! -f "$JOURNAL_FILE" ]; then
    echo "Error: JOURNAL file '$JOURNAL_FILE' does not exist or is not readable."
    exit 1
fi

# Extract the filename without the path and extension for logging purposes
FILENAME=$(basename "$JOURNAL_FILE" | sed 's/\.[^.]*$//')

# Show the action to be performed with details
echo "Server: $SERVER"
echo "Action: $ACTION"
echo "Journal file: $JOURNAL_FILE"
echo "Log file will be named based on: $FILENAME"
echo ""
echo "------------------------------------------------------------------"
echo "Action will be applied to:"
cat $JOURNAL_FILE
echo "------------------------------------------------------------------"
echo ""

# Ask for confirmation before proceeding
read -p "Are you sure you want to execute this action? (y/n) " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Action cancelled by user."
    exit 0
fi

# Get the current date and time in the format YYYYMMDD-HHMM
TIMESTAMP=$(date +"%Y%m%d-%H%M")

# Log file path based on the server name, timestamp, and filename without extension
LOG_FILE=".logs/${TIMESTAMP}-${SERVER}-${FILENAME}.log"

# Create the log directory if it doesn't exist
mkdir -p .logs

# Process each JOURNAL listed in the file
while IFS= read -r JOURNAL; do
    # Execute the command with the current JOURNAL and display it on the screen
    echo "Executing: just $ACTION $JOURNAL $SERVER $ARGUMENTS"
    
    # Run the command and capture the output
    OUTPUT=$(SERVER=${SERVER} JOURNAL=${JOURNAL} just "$ACTION" "$JOURNAL" "$SERVER" "$ARUMENTS")
    
    # Display the result in the terminal
    echo "$OUTPUT"

    # Append the output to the log file
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $OUTPUT" >> "$LOG_FILE"
done < "$JOURNAL_FILE"

echo "Logs saved to: $LOG_FILE"

