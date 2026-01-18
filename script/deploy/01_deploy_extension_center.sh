#!/bin/bash

# Ensure environment is initialized
if [ -z "$RPC_URL" ]; then
    echo -e "\033[31mError:\033[0m Environment not initialized. Please run 00_init.sh first."
    return 1
fi

echo "Deploying ExtensionCenter contract..."

forge_script ../DeployExtensionCenter.s.sol:DeployExtensionCenter --sig "run()"

if [ $? -eq 0 ]; then
    # Load deployed address
    source $network_dir/address.extension.center.params
    echo -e "\033[32m✓\033[0m ExtensionCenter deployed at: $centerAddress"
    return 0
else
    echo -e "\033[31m✗\033[0m Failed to deploy ExtensionCenter"
    return 1
fi
