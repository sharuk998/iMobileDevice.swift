import Foundation

// MARK: - Device Connection Type

/// Represents the connection type of an iOS device
public enum DeviceConnectionType: String, Codable {
    case usb = "USB"
    case network = "Network"
    case unknown = "Unknown"
}

// MARK: - Device Info Model

/// Represents information about a connected iOS device
public struct DeviceInfo: Codable, Identifiable, Equatable {
    /// Unique Device Identifier
    public let id: String
    
    /// Device UDID
    public let udid: String
    
    /// Connection type (USB or Network)
    public let connectionType: DeviceConnectionType
    
    /// Device name (if available)
    public let name: String?
    
    /// Product type (e.g., "iPhone9,3")
    public let productType: String?
    
    /// iOS version (e.g., "15.8.4")
    public let iosVersion: String?
    
    /// Serial number
    public let serialNumber: String?
    
    public init(
        udid: String,
        connectionType: DeviceConnectionType,
        name: String? = nil,
        productType: String? = nil,
        iosVersion: String? = nil,
        serialNumber: String? = nil
    ) {
        self.id = udid
        self.udid = udid
        self.connectionType = connectionType
        self.name = name
        self.productType = productType
        self.iosVersion = iosVersion
        self.serialNumber = serialNumber
    }
}

// MARK: - Device Metadata

/// Complete device metadata including raw plist data
public struct DeviceMetadata {
    /// Structured device information
    public let deviceInfo: DeviceInfo
    
    /// Raw plist XML data as string
    public let rawPlistXML: String
    
    /// Raw plist dictionary (if parsed)
    public let rawPlist: [String: Any]?
    
    public init(deviceInfo: DeviceInfo, rawPlistXML: String, rawPlist: [String: Any]? = nil) {
        self.deviceInfo = deviceInfo
        self.rawPlistXML = rawPlistXML
        self.rawPlist = rawPlist
    }
}
