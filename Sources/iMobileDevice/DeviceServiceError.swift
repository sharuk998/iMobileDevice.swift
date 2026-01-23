import Foundation

// MARK: - Device Service Errors

/// Errors that can occur when interacting with iOS devices
public enum DeviceServiceError: LocalizedError, Equatable {
    /// No devices found
    case noDevicesFound
    
    /// Device not found with given UDID
    case deviceNotFound(udid: String)
    
    /// Failed to connect to device
    case connectionFailed(udid: String, code: Int32)
    
    /// Failed to get device information
    case informationRetrievalFailed(udid: String, code: Int32)
    
    /// Failed to pair with device
    case pairingFailed(udid: String, code: Int32)
    
    /// Backup failed
    case backupFailed(udid: String, code: Int32, message: String?)
    
    /// Invalid backup directory
    case invalidBackupDirectory(path: String)
    
    /// Unknown error
    case unknown(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .noDevicesFound:
            return "No iOS devices found. Please connect a device via USB."
        case .deviceNotFound(let udid):
            return "Device with UDID \(udid) not found."
        case .connectionFailed(let udid, let code):
            return "Failed to connect to device \(udid). Error code: \(code)"
        case .informationRetrievalFailed(let udid, let code):
            return "Failed to retrieve information for device \(udid). Error code: \(code)"
        case .pairingFailed(let udid, let code):
            return "Failed to pair with device \(udid). Error code: \(code). Please ensure the device is unlocked and you trust this computer."
        case .backupFailed(let udid, let code, let message):
            let msg = message ?? "Unknown error"
            return "Backup failed for device \(udid). Error code: \(code). \(msg)"
        case .invalidBackupDirectory(let path):
            return "Invalid backup directory: \(path)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}
