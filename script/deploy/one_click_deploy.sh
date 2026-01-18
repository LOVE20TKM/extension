#!/bin/bash

# ------ Step 1: Initialize environment ------
echo -e "\n[Step 1/4] Initializing environment..."
source 00_init.sh $1
if [ $? -ne 0 ]; then
    echo -e "\033[31mError:\033[0m Failed to initialize environment"
    return 1
fi

echo -e "\n========================================="
echo -e "  One-Click Deploy Extension Center"
echo -e "  Network: $network"
echo -e "=========================================\n"

# ------ Step 2: Deploy Extension Center ------
echo -e "\n[Step 2/4] Deploying ExtensionCenter..."
source 01_deploy_extension_center.sh
if [ $? -ne 0 ]; then
    echo -e "\033[31mError:\033[0m Deployment failed"
    return 1
fi

# ------ Step 3: Verify contract (for thinkium70001 networks) ------
if [[ "$network" == thinkium70001* ]]; then
    echo -e "\n[Step 3/4] Verifying contract on explorer..."
    source 02_verify.sh
    if [ $? -ne 0 ]; then
        echo -e "\033[33mWarning:\033[0m Contract verification failed (deployment is still successful)"
    else
        echo -e "\033[32m✓\033[0m Contract verified successfully"
    fi
else
    echo -e "\n[Step 3/4] Skipping contract verification (not a thinkium network)"
fi

# ------ Step 4: Run deployment checks ------
echo -e "\n[Step 4/4] Running deployment checks..."
source 99_check.sh
if [ $? -ne 0 ]; then
    echo -e "\033[31mError:\033[0m Deployment checks failed"
    return 1
fi

echo -e "\n========================================="
echo -e "\033[32m✓ Deployment completed successfully!\033[0m"
echo -e "========================================="
echo -e "Extension Center Address: $centerAddress"
echo -e "Network: $network"
echo -e "=========================================\n"