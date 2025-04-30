#!/bin/bash
set -e

# Start both scripts in background
python /app/hass.py &
python /app/bjornify.py &

# Wait for any of them to exit
wait -n

# Exit with the status of the first one that finishes
exit $?
