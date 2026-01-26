#!/bin/bash

# Build script for iMobileDevice CLI
# Creates a universal binary (arm64 + x86_64) with hardened runtime and Developer ID signing

set -e

# Configuration
PRODUCT_NAME="imobiledevice"
BUNDLE_ID="com.imobiledevice.cli"
# Default Developer ID (can be overridden via environment variable or argument)
DEFAULT_DEVELOPER_ID="Developer ID Application: SUMURI LLC (M2UAN8S5M3)"
DEVELOPER_ID="${1:-${DEVELOPER_ID:-${DEFAULT_DEVELOPER_ID}}}"  # Accept as first argument, environment variable, or use default

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for Developer ID
if [ -z "$DEVELOPER_ID" ]; then
    print_error "Developer ID not set. Please set DEVELOPER_ID environment variable:"
    print_error "  export DEVELOPER_ID='Developer ID Application: Your Name (TEAM_ID)'"
    print_error "Or pass it as an argument:"
    print_error "  ./build-binary.sh 'Developer ID Application: Your Name (TEAM_ID)'"
    exit 1
fi

# Verify Developer ID certificate exists
if ! security find-identity -v -p codesigning | grep -q "$DEVELOPER_ID"; then
    print_warning "Developer ID certificate not found in keychain:"
    print_warning "  $DEVELOPER_ID"
    print_warning "Please ensure the certificate is installed in your keychain."
    print_warning "Continuing anyway, but signing may fail..."
fi

print_info "Building universal binary for $PRODUCT_NAME"
print_info "Developer ID: $DEVELOPER_ID"

# Create build directory
BUILD_DIR=".build/release"
mkdir -p "$BUILD_DIR"

# Clean previous builds
print_info "Cleaning previous builds..."
rm -rf "$BUILD_DIR/${PRODUCT_NAME}-arm64"
rm -rf "$BUILD_DIR/${PRODUCT_NAME}-x86_64"
rm -f "$BUILD_DIR/${PRODUCT_NAME}"

# Get SDK path
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
print_info "Using SDK: $SDK_PATH"

# Detect current architecture
CURRENT_ARCH=$(uname -m)
print_info "Current architecture: $CURRENT_ARCH"

# Build for arm64 (Apple Silicon)
print_info "Building for arm64 (Apple Silicon)..."
# Clean previous arm64 build
rm -rf ".build/arm64-apple-macosx"
rm -f "$BUILD_DIR/${PRODUCT_NAME}-arm64"

if [ "$CURRENT_ARCH" = "arm64" ]; then
    # Native build
    swift build \
        --product iMobileDeviceCLI \
        --configuration release
    # Check multiple possible locations
    if [ -f ".build/arm64-apple-macosx/release/iMobileDeviceCLI" ]; then
        cp ".build/arm64-apple-macosx/release/iMobileDeviceCLI" "$BUILD_DIR/${PRODUCT_NAME}-arm64"
        if [ -f "$BUILD_DIR/${PRODUCT_NAME}-arm64" ]; then
            print_info "Copied arm64 binary from .build/arm64-apple-macosx/release/iMobileDeviceCLI"
        else
            print_error "Failed to copy arm64 binary"
            exit 1
        fi
    elif [ -f ".build/release/iMobileDeviceCLI" ]; then
        # Verify it's actually arm64
        if file ".build/release/iMobileDeviceCLI" | grep -q "arm64"; then
            cp ".build/release/iMobileDeviceCLI" "$BUILD_DIR/${PRODUCT_NAME}-arm64"
            print_info "Copied arm64 binary from .build/release/iMobileDeviceCLI"
        else
            print_error "Built binary is not arm64"
            exit 1
        fi
    else
        print_error "arm64 binary not found after build"
        print_error "Checked: .build/arm64-apple-macosx/release/iMobileDeviceCLI"
        print_error "Checked: .build/release/iMobileDeviceCLI"
        exit 1
    fi
else
    # Cross-compile for arm64
    arch -arm64 swift build \
        --product iMobileDeviceCLI \
        --configuration release
    if [ -f ".build/arm64-apple-macosx/release/iMobileDeviceCLI" ]; then
        cp ".build/arm64-apple-macosx/release/iMobileDeviceCLI" "$BUILD_DIR/${PRODUCT_NAME}-arm64"
    elif [ -f ".build/release/iMobileDeviceCLI" ]; then
        # Verify it's actually arm64
        if file ".build/release/iMobileDeviceCLI" | grep -q "arm64"; then
            cp ".build/release/iMobileDeviceCLI" "$BUILD_DIR/${PRODUCT_NAME}-arm64"
        else
            print_error "Built binary is not arm64"
            exit 1
        fi
    else
        print_error "arm64 binary not found after build"
        exit 1
    fi
fi
print_info "✓ arm64 build complete"

# Build for x86_64 (Intel)
print_info "Building for x86_64 (Intel)..."
# Clean previous x86_64 build (but keep arm64 binary safe)
rm -rf ".build/x86_64-apple-macosx"
rm -f "$BUILD_DIR/${PRODUCT_NAME}-x86_64"
# Ensure arm64 binary is still there (it should be, but verify)
if [ ! -f "$BUILD_DIR/${PRODUCT_NAME}-arm64" ]; then
    print_warning "arm64 binary missing before x86_64 build, attempting to restore..."
    if [ -f ".build/arm64-apple-macosx/release/iMobileDeviceCLI" ]; then
        cp ".build/arm64-apple-macosx/release/iMobileDeviceCLI" "$BUILD_DIR/${PRODUCT_NAME}-arm64"
        print_info "Restored arm64 binary"
    fi
fi

if [ "$CURRENT_ARCH" = "x86_64" ]; then
    # Native build on Intel Mac
    swift build \
        --product iMobileDeviceCLI \
        --configuration release
    if [ -f ".build/x86_64-apple-macosx/release/iMobileDeviceCLI" ]; then
        cp ".build/x86_64-apple-macosx/release/iMobileDeviceCLI" "$BUILD_DIR/${PRODUCT_NAME}-x86_64"
    else
        print_error "x86_64 binary not found after build"
        exit 1
    fi
else
    # Cross-compile for x86_64 on Apple Silicon (requires Rosetta 2)
    if [ "$CURRENT_ARCH" = "arm64" ]; then
        print_info "Switching to Rosetta 2 for x86_64 build..."
        
        # Check if Rosetta 2 is installed
        if ! pgrep -q oahd; then
            print_warning "Rosetta 2 may not be installed. Attempting to install..."
            softwareupdate --install-rosetta --agree-to-license 2>/dev/null || true
        fi
        
        # Build using Rosetta 2 (arch -x86_64 runs the process under Rosetta)
        arch -x86_64 /usr/bin/swift build \
            --product iMobileDeviceCLI \
            --configuration release
        
        # Find and copy the x86_64 binary
        if [ -f ".build/x86_64-apple-macosx/release/iMobileDeviceCLI" ]; then
            cp ".build/x86_64-apple-macosx/release/iMobileDeviceCLI" "$BUILD_DIR/${PRODUCT_NAME}-x86_64"
        elif [ -f ".build/release/iMobileDeviceCLI" ]; then
            # Verify it's actually x86_64
            if file ".build/release/iMobileDeviceCLI" | grep -q "x86_64"; then
                cp ".build/release/iMobileDeviceCLI" "$BUILD_DIR/${PRODUCT_NAME}-x86_64"
            else
                print_warning "Built binary is not x86_64. Skipping x86_64 architecture."
            fi
        else
            print_warning "Could not find x86_64 binary. Skipping x86_64 architecture."
        fi
    else
        print_warning "Unknown architecture: $CURRENT_ARCH. Cannot build for x86_64."
    fi
fi
print_info "✓ x86_64 build complete"

# Re-copy arm64 binary if it was lost during x86_64 build
if [ ! -f "$BUILD_DIR/${PRODUCT_NAME}-arm64" ]; then
    print_info "Re-copying arm64 binary (may have been affected by x86_64 build)..."
    if [ -f ".build/arm64-apple-macosx/release/iMobileDeviceCLI" ]; then
        cp ".build/arm64-apple-macosx/release/iMobileDeviceCLI" "$BUILD_DIR/${PRODUCT_NAME}-arm64"
        print_info "✓ arm64 binary restored"
    else
        print_warning "arm64 binary source not found at .build/arm64-apple-macosx/release/iMobileDeviceCLI"
    fi
fi

# Verify both binaries exist and show their architectures
print_info "Verifying built binaries..."
if [ -f "$BUILD_DIR/${PRODUCT_NAME}-arm64" ]; then
    print_info "  arm64 binary: $(file "$BUILD_DIR/${PRODUCT_NAME}-arm64" | cut -d: -f2)"
else
    print_warning "  arm64 binary not found in $BUILD_DIR"
fi

if [ -f "$BUILD_DIR/${PRODUCT_NAME}-x86_64" ]; then
    print_info "  x86_64 binary: $(file "$BUILD_DIR/${PRODUCT_NAME}-x86_64" | cut -d: -f2)"
else
    print_warning "  x86_64 binary not found in $BUILD_DIR"
fi

# Check if we have both architectures
if [ -f "$BUILD_DIR/${PRODUCT_NAME}-arm64" ] && [ -f "$BUILD_DIR/${PRODUCT_NAME}-x86_64" ]; then
    # Create universal binary
    print_info "Creating universal binary..."
    lipo -create \
        "$BUILD_DIR/${PRODUCT_NAME}-arm64" \
        "$BUILD_DIR/${PRODUCT_NAME}-x86_64" \
        -output "$BUILD_DIR/${PRODUCT_NAME}"
    
    # Verify architectures
    print_info "Verifying universal binary architectures..."
    lipo -info "$BUILD_DIR/${PRODUCT_NAME}"
else
    # Use single architecture binary
    print_warning "Only one architecture available. Using single-architecture binary."
    if [ -f "$BUILD_DIR/${PRODUCT_NAME}-arm64" ]; then
        cp "$BUILD_DIR/${PRODUCT_NAME}-arm64" "$BUILD_DIR/${PRODUCT_NAME}"
        print_info "Using arm64-only binary"
    elif [ -f "$BUILD_DIR/${PRODUCT_NAME}-x86_64" ]; then
        cp "$BUILD_DIR/${PRODUCT_NAME}-x86_64" "$BUILD_DIR/${PRODUCT_NAME}"
        print_info "Using x86_64-only binary"
    else
        print_error "No binary found in $BUILD_DIR!"
        print_error "Expected files:"
        print_error "  - $BUILD_DIR/${PRODUCT_NAME}-arm64"
        print_error "  - $BUILD_DIR/${PRODUCT_NAME}-x86_64"
        exit 1
    fi
    lipo -info "$BUILD_DIR/${PRODUCT_NAME}"
fi

# Bundle OpenSSL framework with the binary
print_info "Bundling OpenSSL framework..."
OPENSSL_FRAMEWORK_SRC=""
# Try to find OpenSSL framework in build artifacts
for possible_path in \
    ".build/checkouts/OpenSSL/Frameworks/macosx/OpenSSL.framework" \
    ".build/arm64-apple-macosx/release/OpenSSL.framework" \
    ".build/x86_64-apple-macosx/release/OpenSSL.framework" \
    ".build/release/OpenSSL.framework"; do
    if [ -d "$possible_path" ]; then
        OPENSSL_FRAMEWORK_SRC="$possible_path"
        break
    fi
done

if [ -z "$OPENSSL_FRAMEWORK_SRC" ]; then
    print_warning "OpenSSL framework not found in build artifacts. Searching..."
    OPENSSL_FRAMEWORK_SRC=$(find .build -name "OpenSSL.framework" -type d -path "*/macosx/*" 2>/dev/null | head -1)
fi

if [ -n "$OPENSSL_FRAMEWORK_SRC" ] && [ -d "$OPENSSL_FRAMEWORK_SRC" ]; then
    print_info "Found OpenSSL framework at: $OPENSSL_FRAMEWORK_SRC"
    
    # Create Frameworks directory next to binary (same directory as executable)
    FRAMEWORKS_DIR="$BUILD_DIR/Frameworks"
    mkdir -p "$FRAMEWORKS_DIR"
    
    # Copy OpenSSL framework
    print_info "Copying OpenSSL framework..."
    cp -R "$OPENSSL_FRAMEWORK_SRC" "$FRAMEWORKS_DIR/"
    
    # Check if we need to create a universal framework (if both arm64 and x86_64 exist)
    ARM64_OPENSSL=$(find .build -name "OpenSSL.framework" -type d -path "*/arm64-apple-macosx/*" 2>/dev/null | head -1)
    X86_64_OPENSSL=$(find .build -name "OpenSSL.framework" -type d -path "*/x86_64-apple-macosx/*" 2>/dev/null | head -1)
    
    # Check if the copied framework is already universal
    COPIED_BINARY="$FRAMEWORKS_DIR/OpenSSL.framework/Versions/A/OpenSSL"
    if [ -f "$COPIED_BINARY" ]; then
        ARCHS=$(lipo -info "$COPIED_BINARY" 2>/dev/null | grep -o "arm64\|x86_64" | sort -u)
        ARCH_COUNT=$(echo "$ARCHS" | wc -l | tr -d ' ')
        
        if [ "$ARCH_COUNT" -gt 1 ]; then
            print_info "OpenSSL framework is already universal (contains: $ARCHS)"
        elif [ -n "$ARM64_OPENSSL" ] && [ -n "$X86_64_OPENSSL" ]; then
            # Try to create universal framework from architecture-specific ones
            ARM64_BINARY="$ARM64_OPENSSL/Versions/A/OpenSSL"
            X86_64_BINARY="$X86_64_OPENSSL/Versions/A/OpenSSL"
            
            if [ -f "$ARM64_BINARY" ] && [ -f "$X86_64_BINARY" ]; then
                # Verify they have different architectures
                ARM64_ARCHS=$(lipo -info "$ARM64_BINARY" 2>/dev/null | grep -o "arm64\|x86_64" | sort -u)
                X86_64_ARCHS=$(lipo -info "$X86_64_BINARY" 2>/dev/null | grep -o "arm64\|x86_64" | sort -u)
                
                if [ "$ARM64_ARCHS" != "$X86_64_ARCHS" ]; then
                    print_info "Creating universal OpenSSL framework from architecture-specific builds..."
                    lipo -create "$ARM64_BINARY" "$X86_64_BINARY" -output "$COPIED_BINARY"
                    print_info "✓ Universal OpenSSL framework created"
                else
                    print_info "OpenSSL frameworks have same architecture, using existing"
                fi
            fi
        else
            print_info "Using single-architecture OpenSSL framework"
        fi
    fi
    
    # Remove existing signature if present, then sign the framework
    print_info "Signing OpenSSL framework..."
    codesign --remove-signature "$FRAMEWORKS_DIR/OpenSSL.framework" 2>/dev/null || true
    codesign --force --sign "$DEVELOPER_ID" \
        --options runtime \
        --timestamp \
        --verbose \
        "$FRAMEWORKS_DIR/OpenSSL.framework" || print_warning "Failed to sign OpenSSL framework (may need to run with sudo or fix permissions)"
    
    # Update binary's rpath to point to bundled framework
    print_info "Updating binary rpath to use bundled OpenSSL framework..."
    # Update the OpenSSL library path in the binary to use @executable_path/Frameworks
    # (Frameworks directory should be in the same directory as the binary)
    install_name_tool -change "@rpath/OpenSSL.framework/Versions/A/OpenSSL" "@executable_path/Frameworks/OpenSSL.framework/Versions/A/OpenSSL" "$BUILD_DIR/${PRODUCT_NAME}" 2>/dev/null || \
    print_warning "Could not update OpenSSL library path"
    
    # Also add rpath for @executable_path/Frameworks (in case it's needed)
    install_name_tool -add_rpath "@executable_path/Frameworks" "$BUILD_DIR/${PRODUCT_NAME}" 2>/dev/null || true
    
    print_info "✓ OpenSSL framework bundled"
else
    print_warning "OpenSSL framework not found. Binary may not work on other machines."
    print_warning "Searched in: .build/checkouts/OpenSSL/Frameworks/macosx/"
fi

# Enable hardened runtime
print_info "Enabling hardened runtime..."
codesign --force --sign "$DEVELOPER_ID" \
    --options runtime \
    --timestamp \
    --verbose \
    "$BUILD_DIR/${PRODUCT_NAME}"

# Verify code signing
print_info "Verifying code signature..."
codesign -vvv --deep --strict "$BUILD_DIR/${PRODUCT_NAME}"
# Note: spctl may show "rejected" for command-line tools (not apps) - this is normal
# The important part is that codesign verification passes
if codesign -vvv "$BUILD_DIR/${PRODUCT_NAME}" 2>&1 | grep -q "valid on disk"; then
    print_info "✓ Code signature is valid"
else
    print_error "Code signature verification failed"
    exit 1
fi

print_info "✓ Universal binary created successfully!"
print_info "Binary location: $BUILD_DIR/${PRODUCT_NAME}"
if [ -d "$FRAMEWORKS_DIR" ]; then
    print_info "Frameworks bundled: $FRAMEWORKS_DIR"
    print_info ""
    print_info "To distribute, copy both the binary and Frameworks directory:"
    print_info "  cp $BUILD_DIR/${PRODUCT_NAME} /path/to/destination/"
    print_info "  cp -R $FRAMEWORKS_DIR /path/to/destination/"
fi
print_info ""
print_info "To notarize the binary, run:"
print_info "  xcrun notarytool submit $BUILD_DIR/${PRODUCT_NAME} --keychain-profile 'AC_PASSWORD' --wait"
print_info ""
print_info "Or use altool (deprecated):"
print_info "  xcrun altool --notarize-app --primary-bundle-id '$BUNDLE_ID' --username 'your@email.com' --password '@keychain:AC_PASSWORD' --file $BUILD_DIR/${PRODUCT_NAME}"
