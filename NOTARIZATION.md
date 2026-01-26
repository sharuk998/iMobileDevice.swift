# Notarization Guide for iMobileDevice CLI

## Current Status

✅ **Already Configured:**
- Main binary (`imobiledevice`) is signed with Developer ID
- OpenSSL framework is signed with Developer ID
- Hardened runtime is enabled for both
- Universal binary (arm64 + x86_64) is created
- Frameworks are bundled correctly

## Notarization Requirements

### 1. Code Signing (✅ Already Done)

**Main Binary:**
- Signed with: `Developer ID Application: SUMURI LLC (M2UAN8S5M3)`
- Hardened runtime: ✅ Enabled
- Location: `.build/release/imobiledevice`

**OpenSSL Framework:**
- Signed with: `Developer ID Application: SUMURI LLC (M2UAN8S5M3)`
- Hardened runtime: ✅ Enabled
- Location: `.build/release/Frameworks/OpenSSL.framework`

### 2. Using in Xcode Project

If you add the `dist` folder to an Xcode project:

**Option A: Copy to Xcode Project (Recommended)**
1. Copy `imobiledevice` binary to your Xcode project
2. Copy `Frameworks/OpenSSL.framework` to your Xcode project
3. Add both to your Xcode target's "Copy Files" build phase
4. Xcode will automatically re-sign them during build (if configured)

**Option B: Embed in App Bundle**
1. Add `imobiledevice` to your app's `Contents/MacOS/` directory
2. Add `OpenSSL.framework` to your app's `Contents/Frameworks/` directory
3. Update the binary's rpath if needed: `@executable_path/../Frameworks`

### 3. Notarization Checklist

Before submitting for notarization, verify:

```bash
# 1. Verify code signatures
codesign -vvv --deep --strict .build/release/imobiledevice
codesign -vvv --deep --strict .build/release/Frameworks/OpenSSL.framework

# 2. Check hardened runtime
codesign -dvvv .build/release/imobiledevice | grep runtime
codesign -dvvv .build/release/Frameworks/OpenSSL.framework | grep runtime

# 3. Verify all dependencies are signed
otool -L .build/release/imobiledevice | grep -v "@rpath\|@executable_path"
```

### 4. Notarization Process

**Using notarytool (Recommended):**
```bash
# Create a zip archive
cd .build/release
zip -r imobiledevice.zip imobiledevice Frameworks

# Submit for notarization
xcrun notarytool submit imobiledevice.zip \
    --keychain-profile "AC_PASSWORD" \
    --wait \
    --team-id "M2UAN8S5M3"
```

**Using altool (Deprecated):**
```bash
xcrun altool --notarize-app \
    --primary-bundle-id "com.imobiledevice.cli" \
    --username "your@email.com" \
    --password "@keychain:AC_PASSWORD" \
    --file .build/release/imobiledevice
```

### 5. Common Issues

**Issue: "The binary is not signed"**
- Solution: Ensure both binary and framework are signed with Developer ID

**Issue: "Hardened runtime is not enabled"**
- Solution: Already enabled in build script with `--options runtime`

**Issue: "Invalid signature"**
- Solution: Re-sign both binary and framework after any modifications

**Issue: "Framework not found"**
- Solution: Ensure Frameworks directory is in the same directory as binary, or update rpath

### 6. Xcode Integration

If adding to Xcode project:

1. **Add to Project:**
   - Drag `imobiledevice` and `Frameworks` folder into Xcode
   - Ensure "Copy items if needed" is checked
   - Add to target

2. **Code Signing Settings:**
   - In Build Settings, set "Code Signing Identity" to "Developer ID Application"
   - Enable "Hardened Runtime" (already enabled in binary)
   - Set "Code Signing Entitlements" if needed

3. **Build Phases:**
   - Add "Copy Files" phase if needed
   - Ensure both binary and framework are included

4. **Archive & Notarize:**
   - Archive your app in Xcode
   - Xcode will handle notarization automatically if configured
   - Or manually notarize using the commands above

### 7. Verification After Notarization

```bash
# Check notarization status
xcrun notarytool history --keychain-profile "AC_PASSWORD"

# Verify Gatekeeper acceptance
spctl --assess --verbose .build/release/imobiledevice
```

## Summary

✅ **You're already set up correctly!**

- Both binary and framework are signed
- Hardened runtime is enabled
- Universal binary is created
- Frameworks are bundled

**To notarize:**
1. Create a zip of both `imobiledevice` and `Frameworks` directory
2. Submit to Apple's notarization service
3. Wait for approval
4. Staple the ticket (optional but recommended)

**For Xcode projects:**
- The binaries are already signed, so Xcode will respect those signatures
- Xcode may re-sign during build (which is fine)
- Ensure "Hardened Runtime" is enabled in Xcode build settings
- Frameworks in `Frameworks/` directory will work correctly

**For SPM (Swift Package Manager):**
- See `SPM_DISTRIBUTION.md` for detailed instructions
- Binaries must be **pre-signed and notarized** before adding to SPM
- SPM doesn't re-sign binaries, so they must be ready before distribution
- Consider distributing CLI separately (GitHub Releases, Homebrew) while keeping libraries in SPM
