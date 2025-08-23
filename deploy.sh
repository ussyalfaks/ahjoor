#!/bin/bash

# Ahjoor Savings Contract Deployment Script
# This script deploys the Ahjoor Savings contract to Starknet Sepolia testnet

set -e

echo "🚀 Starting Ahjoor Savings Contract Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if account is deployed
print_status "Checking if account is deployed..."
ACCOUNT_INFO=$(sncast account list | grep -A 10 "deployer:")
if echo "$ACCOUNT_INFO" | grep -q "deployed: false"; then
    print_warning "Account not deployed yet. Please fund your account first."
    ACCOUNT_ADDRESS=$(echo "$ACCOUNT_INFO" | grep "address:" | awk '{print $2}')
    print_status "Account address: $ACCOUNT_ADDRESS"
    print_status "Required funding: ~0.00289 STRK"
    print_status "After funding, run: sncast account deploy --name deployer"
    exit 1
fi

print_success "Account is deployed and ready!"

# Build the contract
print_status "Building contract..."
scarb build
print_success "Contract built successfully!"

# Declare the contract
print_status "Declaring AhjoorSavings contract..."
DECLARE_OUTPUT=$(sncast declare --contract-name AhjoorSavings)
CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep "class_hash" | awk '{print $2}')
print_success "Contract declared with class hash: $CLASS_HASH"

# For testing purposes, we'll use a mock STARK address
# In production, you would use the actual STARK contract address
MOCK_STRK_ADDRESS="0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d"  # STRK on Sepolia
OWNER_ADDRESS=$(sncast account list | grep -A 10 "deployer:" | grep "address:" | awk '{print $2}')

print_status "Deploying AhjoorSavings contract..."
print_status "STARK Token Address: $MOCK_STRK_ADDRESS"
print_status "Owner Address: $OWNER_ADDRESS"

# Deploy the contract
DEPLOY_OUTPUT=$(sncast deploy --class-hash $CLASS_HASH --constructor-calldata $MOCK_STRK_ADDRESS $OWNER_ADDRESS)
CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "contract_address" | awk '{print $2}')

print_success "🎉 Ahjoor Savings Contract deployed successfully!"
print_success "Contract Address: $CONTRACT_ADDRESS"
print_success "Class Hash: $CLASS_HASH"
print_success "Owner: $OWNER_ADDRESS"

# Save deployment info to file
cat > deployment_info.txt << EOF
Ahjoor Savings Contract Deployment Information
============================================
Network: Sepolia Testnet
Contract Address: $CONTRACT_ADDRESS
Class Hash: $CLASS_HASH
Owner Address: $OWNER_ADDRESS
STARK Token Address: $MOCK_STRK_ADDRESS
Deployment Date: $(date)
EOF

print_success "Deployment information saved to deployment_info.txt"

# Optional: Deploy Mock STARK for testing
read -p "Do you want to deploy Mock STARK for testing? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Declaring MockSTRK contract..."
    MOCK_DECLARE_OUTPUT=$(sncast declare --contract-name MockSTRK)
    MOCK_CLASS_HASH=$(echo "$MOCK_DECLARE_OUTPUT" | grep "class_hash" | awk '{print $2}')
    
    print_status "Deploying MockSTRK contract..."
    MOCK_DEPLOY_OUTPUT=$(sncast deploy --class-hash $MOCK_CLASS_HASH)
    MOCK_CONTRACT_ADDRESS=$(echo "$MOCK_DEPLOY_OUTPUT" | grep "contract_address" | awk '{print $2}')
    
    print_success "Mock STARK deployed at: $MOCK_CONTRACT_ADDRESS"
    
    # Update deployment info
    cat >> deployment_info.txt << EOF

Mock STARK Contract (for testing)
================================
Mock STARK Address: $MOCK_CONTRACT_ADDRESS
Mock STARK Class Hash: $MOCK_CLASS_HASH
EOF
fi

print_success "🎉 Deployment completed successfully!"
print_status "You can now interact with your contract at: $CONTRACT_ADDRESS"
print_status "View on StarkScan: https://sepolia.starkscan.co/contract/$CONTRACT_ADDRESS"
