#!/bin/bash

echo "========================================="
echo "Verifying Extension Center Configuration"
echo "========================================="

# Ensure environment is initialized
if [ -z "$centerAddress" ]; then
    echo -e "\033[31mError:\033[0m Extension center address not set"
    return 1
fi

echo -e "\nExtension Center Address: $centerAddress\n"

# Track failures
failed_checks=0

# Check uniswapV2FactoryAddress
check_equal "extensionCenter: uniswapV2FactoryAddress" $uniswapV2FactoryAddress $(cast_call $centerAddress "uniswapV2FactoryAddress()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check launchAddress
check_equal "extensionCenter: launchAddress" $launchAddress $(cast_call $centerAddress "launchAddress()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check stakeAddress
check_equal "extensionCenter: stakeAddress" $stakeAddress $(cast_call $centerAddress "stakeAddress()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check submitAddress
check_equal "extensionCenter: submitAddress" $submitAddress $(cast_call $centerAddress "submitAddress()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check voteAddress
check_equal "extensionCenter: voteAddress" $voteAddress $(cast_call $centerAddress "voteAddress()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check joinAddress
check_equal "extensionCenter: joinAddress" $joinAddress $(cast_call $centerAddress "joinAddress()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check randomAddress
check_equal "extensionCenter: randomAddress" $randomAddress $(cast_call $centerAddress "randomAddress()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check verifyAddress
check_equal "extensionCenter: verifyAddress" $verifyAddress $(cast_call $centerAddress "verifyAddress()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Check mintAddress
check_equal "extensionCenter: mintAddress" $mintAddress $(cast_call $centerAddress "mintAddress()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

# Summary
echo "========================================="
if [ $failed_checks -eq 0 ]; then
    echo -e "\033[32m✓ All checks passed (9/9)\033[0m"
    echo "========================================="
    return 0
else
    echo -e "\033[31m✗ $failed_checks check(s) failed\033[0m"
    echo "========================================="
    return 1
fi