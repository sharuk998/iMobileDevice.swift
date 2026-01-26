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
    
    /// Lists all connected devices as a plist array (XML format)
    /// - Returns: XML string containing an array of device plists
    /// - Throws: DeviceServiceError if operation fails
    public func listDevicesAsPlist() throws -> String {
        let devices = try deviceService.listConnectedDevices()
        
        // Create a plist array to hold all device plists
        let devicesArray = plist_new_array()
        defer { plist_free(devicesArray) }
        
        // For each device, get its full metadata and parse the plist XML
        for device in devices {
            var devicePlist: plist_t? = nil
            
            // Try to get full metadata, but fall back to basic info if connection fails
            if let metadata = try? deviceService.getDeviceMetadata(udid: device.udid),
               !metadata.rawPlistXML.isEmpty {
                let xmlData = metadata.rawPlistXML
                
                // Parse the XML into a plist
                var parsedPlist: plist_t? = nil
                let parseResult = plist_from_xml(xmlData, UInt32(xmlData.utf8.count), &parsedPlist)
                
                if parseResult.rawValue == 0, let plist = parsedPlist {
                    devicePlist = plist
                }
            }
            
            // If we don't have a plist yet (connection failed or parsing failed), create a minimal dict
            if devicePlist == nil {
                let fallbackPlist = plist_new_dict()
                plist_dict_set_item(fallbackPlist, "UniqueDeviceID", plist_new_string(device.udid))
                if let name = device.name {
                    plist_dict_set_item(fallbackPlist, "DeviceName", plist_new_string(name))
                }
                if let productType = device.productType {
                    plist_dict_set_item(fallbackPlist, "ProductType", plist_new_string(productType))
                }
                if let iosVersion = device.iosVersion {
                    plist_dict_set_item(fallbackPlist, "ProductVersion", plist_new_string(iosVersion))
                }
                // Add connection type
                let connectionTypeStr = device.connectionType == .usb ? "USB" : (device.connectionType == .network ? "Network" : "Unknown")
                plist_dict_set_item(fallbackPlist, "ConnectionType", plist_new_string(connectionTypeStr))
                devicePlist = fallbackPlist
            }
            
            // Append the device plist to the array
            if let plist = devicePlist {
                plist_array_append_item(devicesArray, plist)
            }
        }
        
        // Convert the array to XML
        var xmlString: UnsafeMutablePointer<CChar>? = nil
        var length: UInt32 = 0
        let xmlResult = plist_to_xml(devicesArray, &xmlString, &length)
        
        guard xmlResult.rawValue == 0, let xml = xmlString else {
            throw DeviceServiceError.unknown(message: "Failed to convert devices array to XML")
        }
        defer { free(xml) }
        
        return String(cString: xml)
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
