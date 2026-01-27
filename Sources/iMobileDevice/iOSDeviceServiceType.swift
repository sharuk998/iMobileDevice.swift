import Foundation

// MARK: - Device Service Protocol

/// Protocol defining device discovery and information retrieval operations
/// Follows Interface Segregation Principle - focused interface for device operations
public protocol iOSDeviceServiceType {
    /// Lists all connected iOS devices
    /// - Returns: Array of device metadata
    /// - Throws: DeviceServiceError if operation fails
    func listConnectedDevices() throws -> [iOSDeviceMetadata]
    
    /// Retrieves detailed metadata for a specific device
    /// - Parameter udid: Device UDID (nil to use first connected device)
    /// - Returns: Complete device metadata including raw plist data
    /// - Throws: DeviceServiceError if operation fails
    func getDeviceMetadata(udid: String?) throws -> iOSDeviceMetadata
}

// MARK: - Backup Service Protocol

/// Protocol defining backup operations
/// Follows Interface Segregation Principle - separate interface for backup operations
public protocol BackupServiceProtocol {
    /// Creates a backup of the specified device
    /// - Parameters:
    ///   - udid: Device UDID (nil to use first connected device)
    ///   - backupPath: Directory where backup will be stored
    ///   - password: Backup password for encrypted backups (nil for unencrypted)
    ///   - forceFull: Whether to force a full backup (default: true)
    /// - Returns: Number of files backed up
    /// - Throws: DeviceServiceError if operation fails
    func createBackup(
        udid: String?,
        backupPath: String,
        password: String?,
        forceFull: Bool
    ) throws -> Int
}
