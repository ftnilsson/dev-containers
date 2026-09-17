#!/bin/sh
set -e
/usr/local/bin/gh-app-token-daemon.sh &
exec squid -N -d 1
