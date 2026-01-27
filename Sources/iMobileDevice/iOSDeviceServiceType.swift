import Foundation

// MARK: - Device Service Protocol

/// Protocol defining device discovery and information retrieval operations
/// Follows Interface Segregation Principle - focused interface for device operations
public protocol iOSDeviceServiceType {
    /// Lists all connected iOS devices
    /// - Returns: Array of device metadata
    /// - Throws: iOSDeviceServiceError if operation fails
    func listConnectedDevices() async throws -> [iOSDeviceMetadata]
    
    /// Retrieves detailed metadata for a specific device
    /// - Parameter udid: Device UDID (nil to use first connected device)
    /// - Returns: Complete device metadata including raw plist data
    /// - Throws: iOSDeviceServiceError if operation fails
    func getDeviceMetadata(udid: String?) async throws -> iOSDeviceMetadata

    /// Creates a backup of the specified device
    /// - Parameters:
    ///   - udid: Device UDID (nil to use first connected device)
    ///   - backupPath: Directory where backup will be stored
    ///   - forceFull: Whether to force a full backup (default: true)
    /// - Returns: Number of files backed up
    /// - Throws: iOSDeviceServiceError if operation fails
    func createBackup(
        udid: String?,
        backupPath: String,
        forceFull: Bool,
        progressHandler: ((Float) -> Void)?
    ) async throws -> Int
    
    func cancelBackup()
}
