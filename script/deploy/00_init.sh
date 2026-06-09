# ------ set network ------
export network=$1
if [ -z "$network" ] || [ ! -d "../network/$network" ]; then
    echo -e "\033[31mError:\033[0m Network parameter is required."
    echo -e "\nAvailable networks:"
    for net in $(ls ../network); do
        echo "  - $net"
    done
    return 1
fi

# ------ dont change below ------
network_dir="../network/$network"

source $network_dir/.account && \
source $network_dir/network.params && \
source $network_dir/address.params

if [ -f "$network_dir/address.extension.center.params" ]; then
    source "$network_dir/address.extension.center.params"
fi

# ------ Request keystore password ------
if [ "$network" = "anvil" ]; then
    if [ -z "$PRIVATE_KEY" ]; then
        echo -e "\033[31mError:\033[0m PRIVATE_KEY is required for anvil deployment."
        return 1
    fi
    export KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD:-}"
    export KEYSTORE_PASSWORD_ACCOUNT="$KEYSTORE_ACCOUNT"
    echo "Using PRIVATE_KEY from anvil .account"
else
    echo -e "\nPlease enter keystore password (for $KEYSTORE_ACCOUNT):"
    read -s KEYSTORE_PASSWORD
    export KEYSTORE_PASSWORD
    echo "Password saved, will not be requested again in this session"
fi

cast_call() {
    local address=$1
    local function_signature=$2
    shift 2
    local args=("$@")

    # echo "Executing cast call: $address $function_signature ${args[@]}"
    cast call "$address" \
        "$function_signature" \
        "${args[@]}" \
        --rpc-url "$RPC_URL"
}
echo "cast_call() loaded"

# Check if two values are equal
check_equal() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    
    # Convert to lowercase for comparison
    expected=$(echo "$expected" | tr '[:upper:]' '[:lower:]')
    actual=$(echo "$actual" | tr '[:upper:]' '[:lower:]')
    
    if [ "$expected" = "$actual" ]; then
        echo -e "\033[32m✓\033[0m $description"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        return 0
    else
        echo -e "\033[31m✗\033[0m $description"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        return 1
    fi
}
echo "check_equal() loaded"


## Using keystore file method
forge_script() {
  if [ "$network" = "anvil" ]; then
    local anvil_build_args=()
    [ -n "$ANVIL_FOUNDRY_OUT" ] && anvil_build_args+=(--out "$ANVIL_FOUNDRY_OUT")
    [ -n "$ANVIL_FOUNDRY_CACHE" ] && anvil_build_args+=(--cache-path "$ANVIL_FOUNDRY_CACHE")

    forge script "$@" \
      --rpc-url $RPC_URL \
      --private-key "$PRIVATE_KEY" \
      --sender $ACCOUNT_ADDRESS \
      --gas-price 5000000000 \
      --gas-limit 50000000 \
      --broadcast \
      --legacy \
      "${anvil_build_args[@]}"
  else
    forge script "$@" \
      --rpc-url $RPC_URL \
      --account $KEYSTORE_ACCOUNT \
      --sender $ACCOUNT_ADDRESS \
      --password "$KEYSTORE_PASSWORD" \
      --gas-price 5000000000 \
      --gas-limit 50000000 \
      --broadcast \
      --legacy \
      $([[ "$network" != thinkium* ]] && echo "--verify --etherscan-api-key $ETHERSCAN_API_KEY")
  fi
}
echo "forge_script() loaded"
