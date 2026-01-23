import Foundation

// MARK: - Combined iOS Device Service

/// Convenience service that combines device and backup operations
/// Follows Facade pattern - provides a simplified interface to complex subsystems
public class iOSDeviceService {
    
    // MARK: - Dependencies
    
    private let deviceService: DeviceServiceProtocol
    private let backupService: BackupServiceProtocol
    
    // MARK: - Initialization
    
    /// Initialize with optional custom services (Dependency Injection)
    /// - Parameters:
    ///   - deviceService: Service for device operations (default: DeviceService())
    ///   - backupService: Service for backup operations (default: BackupService())
    public init(
        deviceService: DeviceServiceProtocol? = nil,
        backupService: BackupServiceProtocol? = nil
    ) {
        let defaultDeviceService = DeviceService()
        self.deviceService = deviceService ?? defaultDeviceService
        self.backupService = backupService ?? BackupService(deviceService: defaultDeviceService)
    }
    
    // MARK: - Device Operations
    
    /// Lists all connected iOS devices
    /// - Returns: Array of device information
    /// - Throws: DeviceServiceError if operation fails
    public func listConnectedDevices() throws -> [DeviceInfo] {
        return try deviceService.listConnectedDevices()
    }
    
    /// Retrieves detailed metadata for a specific device
    /// - Parameter udid: Device UDID (nil to use first connected device)
    /// - Returns: Complete device metadata including raw plist data
    /// - Throws: DeviceServiceError if operation fails
    public func getDeviceMetadata(udid: String? = nil) throws -> DeviceMetadata {
        return try deviceService.getDeviceMetadata(udid: udid)
    }
    
    // MARK: - Backup Operations
    
    /// Creates a backup of the specified device
    /// - Parameters:
    ///   - udid: Device UDID (nil to use first connected device)
    ///   - backupPath: Directory where backup will be stored
    ///   - password: Backup password for encrypted backups (nil for unencrypted)
    ///   - forceFull: Whether to force a full backup (default: true)
    /// - Returns: Number of files backed up
    /// - Throws: DeviceServiceError if operation fails
    public func createBackup(
        udid: String? = nil,
        backupPath: String,
        password: String? = nil,
        forceFull: Bool = true
    ) throws -> Int {
        return try backupService.createBackup(
            udid: udid,
            backupPath: backupPath,
            password: password,
            forceFull: forceFull
        )
    }
}
