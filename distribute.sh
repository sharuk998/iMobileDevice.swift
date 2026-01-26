#!/bin/bash

# Distribution script for iMobileDevice CLI
# Creates a distributable package with the binary and required frameworks

set -e

PRODUCT_NAME="imobiledevice"
BUILD_DIR=".build/release"
DIST_DIR="dist"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if binary exists
if [ ! -f "$BUILD_DIR/${PRODUCT_NAME}" ]; then
    print_warning "Binary not found. Please run ./build-binary.sh first."
    exit 1
fi

# Check if Frameworks directory exists
if [ ! -d "$BUILD_DIR/Frameworks" ]; then
    print_warning "Frameworks directory not found. Please run ./build-binary.sh first."
    exit 1
fi

# Create distribution directory
print_info "Creating distribution package..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Copy binary
cp "$BUILD_DIR/${PRODUCT_NAME}" "$DIST_DIR/"

# Copy Frameworks directory
cp -R "$BUILD_DIR/Frameworks" "$DIST_DIR/"

# Create README
cat > "$DIST_DIR/README.txt" << EOF
iMobileDevice CLI - iOS Device Management Tool

INSTALLATION:
1. Copy both the 'imobiledevice' binary and 'Frameworks' directory to your desired location
2. Keep them in the same directory (Frameworks should be next to the binary)
3. Make the binary executable: chmod +x imobiledevice

USAGE:
  ./imobiledevice list                    - List connected devices
  ./imobiledevice info [UDID]             - Get device information
  ./imobiledevice raw [UDID]              - Print raw plist XML
  ./imobiledevice backup [UDID] [PATH]    - Create device backup

EXAMPLES:
  ./imobiledevice list
  ./imobiledevice info
  ./imobiledevice backup ./my-backup

For more information, run: ./imobiledevice --help
EOF

print_info "✓ Distribution package created in: $DIST_DIR"
print_info ""
print_info "To install system-wide, run:"
print_info "  sudo cp $DIST_DIR/${PRODUCT_NAME} /usr/local/bin/"
print_info "  sudo cp -R $DIST_DIR/Frameworks /usr/local/lib/"
print_info ""
print_info "Or keep them together in a custom location:"
print_info "  cp -R $DIST_DIR/* /path/to/your/installation/"
