import Foundation
import iMobileDevice

// MARK: - CLI Tool

/// iMobileDevice CLI - Command-line tool for iOS device management
/// Usage:
///   imobiledevice list                    - List connected devices
///   imobiledevice info [UDID]            - Get device information
///   imobiledevice backup [UDID] [PATH]   - Create device backup
struct iMobileDeviceCLI {
    
    // MARK: - Properties
    
    private let service: iOSDeviceService
    
    // MARK: - Initialization
    
    init() {
        self.service = iOSDeviceService()
    }
    
    // MARK: - Command Execution
    
    func run() {
        let args = CommandLine.arguments
        
        guard args.count > 1 else {
            printUsage()
            exit(1)
        }
        
        let command = args[1]
        
        do {
            switch command {
            case "list", "ls":
                // Check if --plist flag is provided
                if args.contains("--plist") || args.contains("-p") {
                    try listDevicesAsPlist()
                } else {
                    try listDevices()
                }
                
            case "info":
                let udid = args.count > 2 ? args[2] : nil
                try showDeviceInfo(udid: udid)
                
            case "raw", "plist":
                let udid = args.count > 2 ? args[2] : nil
                try showRawPlist(udid: udid)
                
            case "list-plist", "list-plists":
                try listDevicesAsPlist()
                
            case "backup":
                let udid = args.count > 2 && !args[2].hasPrefix("-") ? args[2] : nil
                let backupPath = getBackupPath(from: args)
                try createBackup(udid: udid, backupPath: backupPath)
                
            case "help", "--help", "-h":
                printUsage()
                exit(0)
                
            case "version", "--version", "-v":
                printVersion()
                exit(0)
                
            default:
                print("Error: Unknown command '\(command)'")
                printUsage()
                exit(1)
            }
        } catch {
            printError(error)
            exit(1)
        }
    }
    
    // MARK: - Commands
    
    private func listDevices() throws {
        let devices = try service.listConnectedDevices()
        
        if devices.isEmpty {
            print("No devices found. Please connect an iOS device via USB.")
            return
        }
        
        print("Found \(devices.count) device(s):\n")
        
        for (index, device) in devices.enumerated() {
            print("Device \(index + 1):")
            print("  UDID: \(device.udid)")
            print("  Connection: \(device.connectionType.displayName)")
            if let name = device.name {
                print("  Name: \(name)")
            }
            if let productType = device.productType {
                print("  Product Type: \(productType)")
            }
            if let iosVersion = device.iosVersion {
                print("  iOS Version: \(iosVersion)")
            }
            print()
        }
    }
    
    private func showDeviceInfo(udid: String?) throws {
        let metadata = try service.getDeviceMetadata(udid: udid)
        let device = metadata.deviceInfo
        
        print("=== Device Information ===\n")
        print("UDID: \(device.udid)")
        print("Connection: \(device.connectionType.displayName)")
        
        if let name = device.name {
            print("Name: \(name)")
        }
        
        if let productType = device.productType {
            print("Product Type: \(productType)")
        }
        
        if let iosVersion = device.iosVersion {
            print("iOS Version: \(iosVersion)")
        }
        
        if let serialNumber = device.serialNumber {
            print("Serial Number: \(serialNumber)")
        }
        
        print("\n--- Raw Device Info (Plist XML) ---")
        print(metadata.rawPlistXML)
        print()
    }
    
    private func showRawPlist(udid: String?) throws {
        let metadata = try service.getDeviceMetadata(udid: udid)
        // Print only the raw plist XML, nothing else
        print(metadata.rawPlistXML)
    }
    
    private func listDevicesAsPlist() throws {
        let plistXML = try service.listDevicesAsPlist()
        // Print only the plist XML, nothing else
        print(plistXML)
    }
    
    private func createBackup(udid: String?, backupPath: String) throws {
        print("=== Creating iOS Backup ===\n")
        
        // Validate device exists
        let devices = try service.listConnectedDevices()
        let targetUDID: String
        
        if let providedUDID = udid {
            guard devices.contains(where: { $0.udid == providedUDID }) else {
                throw DeviceServiceError.deviceNotFound(udid: providedUDID)
            }
            targetUDID = providedUDID
        } else {
            guard let firstDevice = devices.first else {
                throw DeviceServiceError.noDevicesFound
            }
            targetUDID = firstDevice.udid
        }
        
        print("Device: \(targetUDID)")
        print("Backup path: \(backupPath)\n")
        
        print("Starting backup process...")
        print("⚠️  If your device asks for a passcode, please enter it on the device now.")
        print("This may take several minutes depending on device data size.\n")
        
        let fileCount = try service.createBackup(
            udid: targetUDID,
            backupPath: backupPath,
            password: nil,
            forceFull: true
        )
        
        print("\n✓ Backup completed successfully!")
        print("  Backup location: \(backupPath)")
        print("  Files backed up: \(fileCount)")
        print()
    }
    
    // MARK: - Helper Methods
    
    private func getBackupPath(from args: [String]) -> String {
        // Look for -o or --output flag
        if let outputIndex = args.firstIndex(where: { $0 == "-o" || $0 == "--output" }),
           outputIndex + 1 < args.count {
            return args[outputIndex + 1]
        }
        
        // If UDID is provided, backup path might be the third argument
        // Otherwise, use default
        if args.count > 2 && !args[2].hasPrefix("-") {
            // Check if it's a path (contains / or .)
            if args[2].contains("/") || args[2].hasPrefix(".") {
                return args[2]
            }
            // If UDID was provided, backup path might be the 4th argument
            if args.count > 3 && !args[3].hasPrefix("-") {
                return args[3]
            }
        }
        
        // Default backup path
        return "./backup"
    }
    
    private func printUsage() {
        print("""
        iMobileDevice CLI - iOS Device Management Tool
        
        Usage:
          imobiledevice <command> [options]
        
        Commands:
          list, ls                    List all connected iOS devices
          list --plist, list -p       List all devices as plist array (XML)
          list-plist                  List all devices as plist array (XML)
          info [UDID]                 Get detailed information about a device
          raw, plist [UDID]           Print only raw plist XML for a device
          backup [UDID] [PATH]        Create a backup of a device
        
        Options:
          -o, --output PATH           Specify backup output path (for backup command)
          -h, --help                 Show this help message
          -v, --version              Show version information
        
        Examples:
          imobiledevice list
          imobiledevice list --plist
          imobiledevice list-plist
          imobiledevice info
          imobiledevice info 00008030-001A1D1234567890
          imobiledevice raw
          imobiledevice raw 00008030-001A1D1234567890
          imobiledevice backup
          imobiledevice backup 00008030-001A1D1234567890 ./my-backup
          imobiledevice backup -o ./my-backup
        
        """)
    }
    
    private func printVersion() {
        print("iMobileDevice CLI 1.0.0")
    }
    
    private func printError(_ error: Error) {
        if let deviceError = error as? DeviceServiceError {
            switch deviceError {
            case .noDevicesFound:
                print("Error: No devices found. Please connect an iOS device via USB.")
            case .deviceNotFound(let udid):
                print("Error: Device with UDID '\(udid)' not found.")
            case .connectionFailed(let udid, let code):
                print("Error: Failed to connect to device '\(udid)' (error code: \(code))")
            case .informationRetrievalFailed(let udid, let code):
                print("Error: Failed to retrieve information for device '\(udid)' (error code: \(code))")
            case .pairingFailed(let udid, let code):
                print("Error: Failed to pair with device '\(udid)' (error code: \(code))")
                print("  Please ensure the device is unlocked and you trust this computer.")
            case .backupFailed(let udid, let code, let message):
                print("Error: Backup failed for device '\(udid)' (code: \(code)): \(message ?? "Unknown error")")
            case .invalidBackupDirectory(let path):
                print("Error: Invalid backup directory: \(path)")
            case .unknown(let message):
                print("Error: \(message)")
            }
        } else {
            print("Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - DeviceConnectionType Extension

extension DeviceConnectionType {
    var displayName: String {
        switch self {
        case .usb:
            return "USB"
        case .network:
            return "Network"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Main Entry Point

let cli = iMobileDeviceCLI()
cli.run()
