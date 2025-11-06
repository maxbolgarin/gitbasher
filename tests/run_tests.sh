#!/usr/bin/env bash

# Test runner script for gitbasher
# This script installs BATS if needed and runs all tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_VERSION="v1.11.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Gitbasher Test Suite${NC}"
echo "================================"
echo

# Check if bats is installed
if ! command -v bats &> /dev/null; then
    echo -e "${YELLOW}BATS not found. Installing BATS ${BATS_VERSION}...${NC}"

    # Create temp directory for bats installation
    BATS_INSTALL_DIR=$(mktemp -d)
    cd "$BATS_INSTALL_DIR"

    # Clone bats repositories
    git clone --depth 1 --branch ${BATS_VERSION} https://github.com/bats-core/bats-core.git
    git clone --depth 1 https://github.com/bats-core/bats-support.git
    git clone --depth 1 https://github.com/bats-core/bats-assert.git

    # Install bats
    cd bats-core
    sudo ./install.sh /usr/local
    cd ..

    # Install bats libraries
    sudo mkdir -p /usr/local/lib/bats
    sudo cp -r bats-support /usr/local/lib/bats/
    sudo cp -r bats-assert /usr/local/lib/bats/

    # Cleanup
    cd "$SCRIPT_DIR"
    rm -rf "$BATS_INSTALL_DIR"

    echo -e "${GREEN}BATS installed successfully${NC}"
    echo
fi

# Verify bats installation
BATS_PATH=$(command -v bats)
echo "Using BATS from: $BATS_PATH"
echo "BATS version: $(bats --version)"
echo

# Check bash version
echo "Bash version: $BASH_VERSION"
if ((BASH_VERSINFO[0] < 4)); then
    echo -e "${RED}Error: Bash 4.0+ required. Current version: $BASH_VERSION${NC}"
    exit 1
fi
echo -e "${GREEN}Bash version OK${NC}"
echo

# Run tests
echo -e "${YELLOW}Running tests...${NC}"
echo "================================"
echo

cd "$SCRIPT_DIR"

# Run all test files
if [ -n "$1" ]; then
    # Run specific test file
    echo "Running specific test: $1"
    bats "$1"
else
    # Run all tests
    bats *.bats
fi

TEST_EXIT_CODE=$?

echo
echo "================================"
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
else
    echo -e "${RED}Some tests failed!${NC}"
fi

exit $TEST_EXIT_CODE
