# iMobileDevice CLI

Command-line tool for managing iOS devices - list devices, get device information, and create backups.

## Building the Binary

### Prerequisites

1. **Developer ID Certificate**: You need a Developer ID Application certificate from Apple Developer Program
2. **Xcode Command Line Tools**: Ensure Xcode and command line tools are installed

### Build Steps

1. **Set your Developer ID** (one of the following methods):
   ```bash
   # Method 1: Environment variable
   export DEVELOPER_ID='Developer ID Application: Your Name (TEAM_ID)'
   
   # Method 2: Pass as argument
   ./build-binary.sh 'Developer ID Application: Your Name (TEAM_ID)'
   ```

2. **Run the build script**:
   ```bash
   ./build-binary.sh
   ```

   The script will:
   - Build for both arm64 (Apple Silicon) and x86_64 (Intel) architectures
   - Create a universal binary using `lipo`
   - Sign the binary with your Developer ID
   - Enable hardened runtime (required for notarization)
   - Verify the code signature

3. **Find your binary**:
   ```
   .build/release/imobiledevice
   ```

### Notarization

After building, you can notarize the binary with Apple:

```bash
# Using notarytool (recommended)
xcrun notarytool submit .build/release/imobiledevice \
  --keychain-profile 'AC_PASSWORD' \
  --wait

# Or using altool (deprecated)
xcrun altool --notarize-app \
  --primary-bundle-id 'com.imobiledevice.cli' \
  --username 'your@email.com' \
  --password '@keychain:AC_PASSWORD' \
  --file .build/release/imobiledevice
```

## Usage

### List Connected Devices

```bash
./imobiledevice list
# or
./imobiledevice ls
```

Output:
```
Found 1 device(s):

Device 1:
  UDID: 00008030-001A1D1234567890
  Connection: USB
  Name: John's iPhone
  Product Type: iPhone14,2
  iOS Version: 17.0
```

### Get Device Information

```bash
# Get info for first connected device
./imobiledevice info

# Get info for specific device
./imobiledevice info 00008030-001A1D1234567890
```

Output includes:
- Device UDID
- Connection type
- Device name
- Product type
- iOS version
- Serial number
- Raw device info (Plist XML)

### Create Backup

```bash
# Backup first connected device to default location (./backup)
./imobiledevice backup

# Backup specific device to custom location
./imobiledevice backup 00008030-001A1D1234567890 ./my-backup

# Use output flag
./imobiledevice backup -o ./my-backup
```

### Help

```bash
./imobiledevice help
# or
./imobiledevice --help
```

## Requirements

- macOS 11.0 or later
- iOS device connected via USB (or paired via network)
- Device must be trusted/unlocked for backup operations

## Troubleshooting

### "No devices found"
- Ensure your iOS device is connected via USB
- Check that the device is unlocked
- Try unplugging and replugging the USB cable

### "Pairing failed"
- Unlock your iOS device
- Tap "Trust" when prompted on the device
- Ensure the device is not in recovery mode

### "Backup failed"
- Ensure the device is unlocked
- Enter passcode if prompted on the device
- Check that you have sufficient disk space
- Verify the backup directory is writable
