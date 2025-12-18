#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== frps Installer ===${NC}\n"

# Detect architecture and OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Convert architecture to frp format
case "$ARCH" in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    armv7l)
        ARCH="arm"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

# Convert OS to frp format
case "$OS" in
    linux)
        OS="linux"
        ;;
    darwin)
        OS="darwin"
        ;;
    freebsd)
        OS="freebsd"
        ;;
    openbsd)
        OS="openbsd"
        ;;
    *)
        echo -e "${RED}Unsupported operating system: $OS${NC}"
        exit 1
        ;;
esac

# Determine file extension
if [ "$OS" = "windows" ]; then
    FILE_EXT="zip"
else
    FILE_EXT="tar.gz"
fi

echo -e "Detected: ${YELLOW}${OS}_${ARCH}${NC}\n"

# Get latest version
echo "Getting latest version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}Error: Could not get latest version${NC}"
    exit 1
fi

echo -e "Latest version: ${GREEN}v${LATEST_VERSION}${NC}\n"

# Build filename
FILENAME="frp_${LATEST_VERSION}_${OS}_${ARCH}.${FILE_EXT}"
DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v${LATEST_VERSION}/${FILENAME}"

echo "Downloading: $FILENAME"
echo "URL: $DOWNLOAD_URL"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download file
if ! curl -L -o "$FILENAME" "$DOWNLOAD_URL"; then
    echo -e "${RED}Error downloading file${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}Download completed${NC}\n"

# Extract archive
echo "Extracting..."
if [ "$FILE_EXT" = "zip" ]; then
    unzip -q "$FILENAME"
    EXTRACTED_DIR=$(unzip -l "$FILENAME" | grep -m1 '/' | awk '{print $4}' | cut -f1 -d"/")
else
    tar -xzf "$FILENAME"
    EXTRACTED_DIR=$(tar -tzf "$FILENAME" | head -1 | cut -f1 -d"/")
fi

# Find frps binary
FRPS_PATH="$EXTRACTED_DIR/frps"

if [ ! -f "$FRPS_PATH" ]; then
    echo -e "${RED}Error: frps binary not found in archive${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Copy to /usr/local/bin
echo "Installing frps to /usr/local/bin..."
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Root permissions required to copy to /usr/local/bin${NC}"
    sudo cp "$FRPS_PATH" /usr/local/bin/frps
    sudo chmod +x /usr/local/bin/frps
else
    cp "$FRPS_PATH" /usr/local/bin/frps
    chmod +x /usr/local/bin/frps
fi

# Cleanup
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo -e "\n${GREEN}✓ Installation completed${NC}"
echo -e "Installed version: ${GREEN}$(frps --version 2>&1 | head -1)${NC}"
echo -e "\nTo verify: ${YELLOW}frps --version${NC}"