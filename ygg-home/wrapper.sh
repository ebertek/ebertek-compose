#!/bin/bash
python /app/hass.py &
python /app/bjornify.py
wait -n
exit $?
