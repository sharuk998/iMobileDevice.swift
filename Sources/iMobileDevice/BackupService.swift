import Foundation

// MARK: - Backup Service Implementation

/// Service class for creating iOS device backups
/// Follows SOLID principles:
/// - Single Responsibility: Handles backup operations only
/// - Open/Closed: Can be extended via protocol conformance
/// - Liskov Substitution: Implements BackupServiceProtocol
/// - Interface Segregation: Separate protocol for backup operations
/// - Dependency Inversion: Depends on DeviceServiceProtocol for device discovery
public class BackupService: BackupServiceProtocol {
    
    // MARK: - Dependencies
    
    private let deviceService: DeviceServiceProtocol
    
    // MARK: - Initialization
    
    /// Initialize with a device service
    /// - Parameter deviceService: Service for device operations (Dependency Injection)
    public init(deviceService: DeviceServiceProtocol = DeviceService()) {
        self.deviceService = deviceService
    }
    
    // MARK: - BackupServiceProtocol Implementation
    
    public func createBackup(
        udid: String?,
        backupPath: String,
        password: String?,
        forceFull: Bool
    ) throws -> Int {
        // Validate backup directory
        let fileManager = FileManager.default
        let backupURL = URL(fileURLWithPath: backupPath)
        
        // Create backup directory if it doesn't exist
        if !fileManager.fileExists(atPath: backupPath) {
            do {
                try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw DeviceServiceError.invalidBackupDirectory(path: backupPath)
            }
        }
        
        // Get device UDID
        let deviceUDID: String
        if let providedUDID = udid {
            deviceUDID = providedUDID
        } else {
            // Get first connected device
            let devices = try deviceService.listConnectedDevices()
            guard let firstDevice = devices.first else {
                throw DeviceServiceError.noDevicesFound
            }
            deviceUDID = firstDevice.udid
        }
        
        // Construct command-line arguments for idevicebackup2_main
        var args = ["idevicebackup2", "-u", deviceUDID, "backup"]
        
        if forceFull {
            args.append("--full")
        }
        
        if let password = password {
            args.append("--password")
            args.append(password)
        }
        
        args.append(backupPath)
        
        // Allocate memory for argv array
        let argc = Int32(args.count)
        let argv = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: args.count + 1)
        defer { argv.deallocate() }
        
        // Allocate memory for each argument string
        var cStrings: [UnsafeMutablePointer<CChar>] = []
        defer {
            for cString in cStrings {
                cString.deallocate()
            }
        }
        
        for (index, arg) in args.enumerated() {
            let cString = strdup(arg)
            guard let cString = cString else {
                throw DeviceServiceError.backupFailed(udid: deviceUDID, code: -1, message: "Failed to allocate memory for argument")
            }
            cStrings.append(cString)
            argv[index] = cString
        }
        argv[args.count] = nil // NULL terminator
        
        // Call the main function directly from idevicebackup2.c
        let result = idevicebackup2_main(argc, argv)
        
        if result == 0 {
            // Success - count files in backup directory
            let fileCount = countFilesInBackup(backupPath: backupPath, udid: deviceUDID)
            return fileCount
        } else {
            throw DeviceServiceError.backupFailed(
                udid: deviceUDID,
                code: result,
                message: "Backup process exited with code \(result)"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func countFilesInBackup(backupPath: String, udid: String) -> Int {
        let fileManager = FileManager.default
        let deviceBackupPath = (backupPath as NSString).appendingPathComponent(udid)
        
        guard let enumerator = fileManager.enumerator(atPath: deviceBackupPath) else {
            return 0
        }
        
        var count = 0
        while enumerator.nextObject() != nil {
            count += 1
        }
        
        return count
    }
}

// MARK: - C Function Declaration

/// Direct call to main() from idevicebackup2.c (renamed to idevicebackup2_main)
@_silgen_name("idevicebackup2_main")
private func idevicebackup2_main(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32
