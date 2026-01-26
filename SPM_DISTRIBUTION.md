# Adding CLI Binary to Swift Package Manager (SPM)

## Overview

To distribute the `imobiledevice` CLI binary and OpenSSL framework via SPM, you have several options. SPM doesn't automatically handle code signing or notarization, so binaries must be **pre-signed and notarized** before being added to the package.

## Option 1: Binary Target with Zip Archive (Recommended)

This is the cleanest approach for distributing a CLI tool via SPM.

### Step 1: Create Distribution Archive

```bash
# Create a zip with binary and frameworks
cd .build/release
zip -r imobiledevice-cli.zip imobiledevice Frameworks
```

### Step 2: Host the Archive

Upload the zip to a URL (GitHub Releases, your server, etc.):
- Example: `https://github.com/yourusername/iMobileDevice/releases/download/v1.0.0/imobiledevice-cli.zip`

### Step 3: Add to Package.swift

```swift
// In your Package.swift
let package = Package(
    name: "iMobileDevice",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        // ... existing products ...
        
        // Add executable product
        .executable(
            name: "imobiledevice",
            targets: ["iMobileDeviceCLIBinary"]
        ),
    ],
    targets: [
        // ... existing targets ...
        
        // Binary target for CLI
        .binaryTarget(
            name: "iMobileDeviceCLIBinary",
            url: "https://github.com/yourusername/iMobileDevice/releases/download/v1.0.0/imobiledevice-cli.zip",
            checksum: "abc123..." // Calculate with: swift package compute-checksum imobiledevice-cli.zip
        ),
    ]
)
```

### Step 4: Create Wrapper Executable Target

Since SPM binary targets can't be directly executable, create a wrapper:

```swift
.executableTarget(
    name: "iMobileDeviceCLI",
    dependencies: ["iMobileDeviceCLIBinary"],
    path: "Sources/iMobileDeviceCLI",
    sources: ["main.swift"]
)
```

And in `main.swift`, you'd need to locate and execute the binary from the bundle.

**Limitation**: This approach is complex because SPM doesn't provide a direct way to execute bundled binaries.

## Option 2: Include as Resource (For Xcode Projects)

If you're primarily targeting Xcode projects that use this SPM package:

### Step 1: Create Resources Directory

```bash
mkdir -p Resources/imobiledevice-cli
cp .build/release/imobiledevice Resources/imobiledevice-cli/
cp -R .build/release/Frameworks Resources/imobiledevice-cli/
```

### Step 2: Add to Package.swift

```swift
.target(
    name: "iMobileDevice",
    dependencies: [
        // ... existing dependencies ...
    ],
    path: "Sources/iMobileDevice",
    resources: [
        .copy("../../Resources/imobiledevice-cli/imobiledevice"),
        .copy("../../Resources/imobiledevice-cli/Frameworks"),
    ]
)
```

### Step 3: Access in Code

```swift
import Foundation

public class CLITool {
    public static func binaryPath() -> URL? {
        guard let resourcePath = Bundle.module.resourcePath else { return nil }
        return URL(fileURLWithPath: resourcePath)
            .appendingPathComponent("imobiledevice-cli")
            .appendingPathComponent("imobiledevice")
    }
    
    public static func execute(_ arguments: [String]) throws {
        guard let binaryPath = binaryPath() else {
            throw NSError(domain: "CLITool", code: 1, userInfo: [NSLocalizedDescriptionKey: "Binary not found"])
        }
        
        let process = Process()
        process.executableURL = binaryPath
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
    }
}
```

## Option 3: XCFramework (For Libraries, Not CLI)

If you want to distribute the OpenSSL framework as a library dependency:

### Step 1: Create XCFramework

```bash
# Create xcframework structure
mkdir -p OpenSSL.xcframework/macos-arm64_x86_64
cp -R .build/release/Frameworks/OpenSSL.framework OpenSSL.xcframework/macos-arm64_x86_64/
```

### Step 2: Add to Package.swift

```swift
.binaryTarget(
    name: "OpenSSL",
    path: "OpenSSL.xcframework"
)
```

## Notarization Requirements for SPM

### ✅ Pre-Notarization (Required)

**Before adding to SPM, you MUST:**

1. **Sign both binary and framework:**
   ```bash
   codesign --force --sign "Developer ID Application: SUMURI LLC (M2UAN8S5M3)" \
       --options runtime \
       --timestamp \
       imobiledevice
   
   codesign --force --sign "Developer ID Application: SUMURI LLC (M2UAN8S5M3)" \
       --options runtime \
       --timestamp \
       Frameworks/OpenSSL.framework
   ```

2. **Notarize the archive:**
   ```bash
   # Create zip
   zip -r imobiledevice-cli.zip imobiledevice Frameworks
   
   # Submit for notarization
   xcrun notarytool submit imobiledevice-cli.zip \
       --keychain-profile "AC_PASSWORD" \
       --wait \
       --team-id "M2UAN8S5M3"
   
   # Staple (optional but recommended)
   xcrun stapler staple imobiledevice-cli.zip
   ```

3. **Verify signatures:**
   ```bash
   codesign -vvv --deep --strict imobiledevice
   codesign -vvv --deep --strict Frameworks/OpenSSL.framework
   ```

### ⚠️ Important Notes

1. **SPM doesn't re-sign**: Binaries in SPM packages are used as-is. They must be signed and notarized before being added to the package.

2. **Hardened Runtime**: Already enabled in your build script (`--options runtime`), so you're good.

3. **Checksums**: SPM requires checksums for binary targets to verify integrity. Calculate with:
   ```bash
   swift package compute-checksum imobiledevice-cli.zip
   ```

4. **Versioning**: Update the URL and checksum in `Package.swift` for each new version.

## Recommended Approach for CLI Tools

For a CLI tool distributed via SPM, **Option 1 (Binary Target)** is recommended, but with a wrapper that:

1. Extracts the binary to a temporary location
2. Executes it with the provided arguments
3. Cleans up after execution

However, this is complex. A simpler approach is:

### Alternative: Separate Distribution

Instead of bundling the CLI in the SPM package:

1. **Keep SPM for libraries only** (iMobileDevice Swift library)
2. **Distribute CLI separately** via:
   - GitHub Releases (with zip)
   - Homebrew formula
   - Direct download from your website

This is cleaner because:
- CLI tools are typically installed system-wide
- SPM is better suited for libraries
- Users can install via `brew install` or download directly
- Notarization is handled once, not per-SPM-version

## Example: Homebrew Distribution

```ruby
# Formula: imobiledevice-cli.rb
class ImobiledeviceCli < Formula
  desc "iOS Device Management CLI Tool"
  homepage "https://github.com/yourusername/iMobileDevice"
  url "https://github.com/yourusername/iMobileDevice/releases/download/v1.0.0/imobiledevice-cli.zip"
  sha256 "abc123..."
  
  def install
    bin.install "imobiledevice"
    frameworks.install "Frameworks/OpenSSL.framework"
  end
end
```

## Summary

**For SPM Distribution:**
- ✅ Pre-sign and notarize before adding to package
- ✅ Use binary target with zip archive
- ✅ Include checksum for verification
- ✅ Hardened runtime is already enabled
- ⚠️ CLI execution from SPM is complex (consider separate distribution)

**Current Status:**
- Your binary and framework are already signed ✅
- Hardened runtime is enabled ✅
- Ready for notarization ✅
- Can be added to SPM after notarization ✅

**Recommendation:**
- For libraries: Use SPM (already set up)
- For CLI tool: Distribute separately (GitHub Releases, Homebrew, etc.)
