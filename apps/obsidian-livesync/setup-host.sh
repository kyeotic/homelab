#!/usr/bin/env bash
# Creates the persistent data directories on the Docker host before first deploy.
set -euo pipefail

ssh root@192.168.0.20 'mkdir -p /mnt/app_config/obsidian-livesync/{data,etc}'
echo "Directories created on Docker host."