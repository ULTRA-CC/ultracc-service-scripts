#!/bin/bash

# Check if plugin name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <plugin_name>"
    exit 1
fi

# Clone the repository with limited history and filter blobs, redirecting all output to /dev/null
git clone --depth=1 --filter=blob:none --no-checkout https://github.com/Novik/ruTorrent.git plugins_repo >/dev/null 2>&1

# Change to the repository directory
cd plugins_repo

# Checkout the specified plugin directory from the repository
git checkout master -- plugins/"$1"

# Move the cloned plugin directory to www/rutorrent/plugins/, redirecting all output to /dev/null
mv "plugins/$1" ../www/rutorrent/plugins/ >/dev/null 2>&1

# Move back to the home directory (~)
cd ~

# Clean up the repository directory
rm -rf plugins_repo

sleep 1 

clear

# Output success message
echo "Plugin '$1' cloned successfully and moved to www/rutorrent/plugins/!"
