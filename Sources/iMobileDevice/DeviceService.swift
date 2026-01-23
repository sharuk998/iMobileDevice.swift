import Foundation

// MARK: - Device Service Implementation

/// Service class for interacting with iOS devices
/// Follows SOLID principles:
/// - Single Responsibility: Handles device discovery and information retrieval
/// - Open/Closed: Can be extended via protocol conformance
/// - Liskov Substitution: Implements DeviceServiceProtocol
/// - Interface Segregation: Separate protocols for different concerns
/// - Dependency Inversion: Depends on protocols, not concrete implementations
public class DeviceService: DeviceServiceProtocol {
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - DeviceServiceProtocol Implementation
    
    public func listConnectedDevices() throws -> [DeviceInfo] {
        var devices: UnsafeMutablePointer<idevice_info_t?>? = nil
        var count: Int32 = 0
        
        let result = idevice_get_device_list_extended(&devices, &count)
        
        guard result == IDEVICE_E_SUCCESS else {
            throw DeviceServiceError.unknown(message: "Failed to get device list. Error code: \(result)")
        }
        
        guard let devicesArray = devices else {
            throw DeviceServiceError.noDevicesFound
        }
        
        var deviceList: [DeviceInfo] = []
        
        for i in 0..<Int(count) {
            guard let deviceInfo = devicesArray[i] else { continue }
            
            let udid = cStringToString(deviceInfo.pointee.udid) ?? ""
            guard !udid.isEmpty else { continue }
            
            let connectionType: DeviceConnectionType
            switch deviceInfo.pointee.conn_type {
            case CONNECTION_USBMUXD:
                connectionType = .usb
            case CONNECTION_NETWORK:
                connectionType = .network
            default:
                connectionType = .unknown
            }
            
            let device = DeviceInfo(
                udid: udid,
                connectionType: connectionType
            )
            
            deviceList.append(device)
        }
        
        // Free the device list
        idevice_device_list_extended_free(devicesArray)
        
        if deviceList.isEmpty {
            throw DeviceServiceError.noDevicesFound
        }
        
        return deviceList
    }
    
    public func getDeviceMetadata(udid: String?) throws -> DeviceMetadata {
        // Get device UDID
        let deviceUDID: String
        if let providedUDID = udid {
            deviceUDID = providedUDID
        } else {
            // Get first connected device
            let devices = try listConnectedDevices()
            guard let firstDevice = devices.first else {
                throw DeviceServiceError.noDevicesFound
            }
            deviceUDID = firstDevice.udid
        }
        
        // Connect to device
        var device: idevice_t? = nil
        let deviceResult = idevice_new(&device, deviceUDID)
        
        guard deviceResult == IDEVICE_E_SUCCESS, let deviceHandle = device else {
            throw DeviceServiceError.connectionFailed(udid: deviceUDID, code: Int32(deviceResult.rawValue))
        }
        defer { idevice_free(deviceHandle) }
        
        // Create lockdown client
        var lockdownClient: lockdownd_client_t? = nil
        let clientResult = lockdownd_client_new_with_handshake(deviceHandle, &lockdownClient, "iMobileDevice")
        
        guard clientResult == LOCKDOWN_E_SUCCESS, let lockdown = lockdownClient else {
            throw DeviceServiceError.connectionFailed(udid: deviceUDID, code: Int32(clientResult.rawValue))
        }
        defer { lockdownd_client_free(lockdown) }
        
        // Get device information
        var deviceInfoPlist: plist_t? = nil
        let infoResult = lockdownd_get_value(lockdown, nil, nil, &deviceInfoPlist)
        
        guard infoResult == LOCKDOWN_E_SUCCESS, let plist = deviceInfoPlist else {
            throw DeviceServiceError.informationRetrievalFailed(udid: deviceUDID, code: Int32(infoResult.rawValue))
        }
        defer { plist_free(plist) }
        
        // Convert plist to XML string
        var xmlString: UnsafeMutablePointer<CChar>? = nil
        var length: UInt32 = 0
        plist_to_xml(plist, &xmlString, &length)
        
        guard let xml = xmlString else {
            throw DeviceServiceError.informationRetrievalFailed(udid: deviceUDID, code: -1)
        }
        defer { free(xml) }
        
        let rawPlistXML = String(cString: xml)
        
        // Extract structured information
        var deviceName: String? = nil
        var productType: String? = nil
        var iosVersion: String? = nil
        var serialNumber: String? = nil
        
        // Extract device name
        var deviceNameNode: plist_t? = nil
        if lockdownd_get_value(lockdown, nil, "DeviceName", &deviceNameNode) == LOCKDOWN_E_SUCCESS,
           let nameNode = deviceNameNode {
            var nameString: UnsafeMutablePointer<CChar>? = nil
            if plist_get_node_type(nameNode) == PLIST_STRING {
                plist_get_string_val(nameNode, &nameString)
                if let name = nameString {
                    deviceName = String(cString: name)
                    free(name)
                }
            }
            plist_free(nameNode)
        }
        
        // Extract product type
        var productTypeNode: plist_t? = nil
        if lockdownd_get_value(lockdown, nil, "ProductType", &productTypeNode) == LOCKDOWN_E_SUCCESS,
           let typeNode = productTypeNode {
            var typeString: UnsafeMutablePointer<CChar>? = nil
            if plist_get_node_type(typeNode) == PLIST_STRING {
                plist_get_string_val(typeNode, &typeString)
                if let type = typeString {
                    productType = String(cString: type)
                    free(type)
                }
            }
            plist_free(typeNode)
        }
        
        // Extract iOS version
        var versionNode: plist_t? = nil
        if lockdownd_get_value(lockdown, nil, "ProductVersion", &versionNode) == LOCKDOWN_E_SUCCESS,
           let verNode = versionNode {
            var versionString: UnsafeMutablePointer<CChar>? = nil
            if plist_get_node_type(verNode) == PLIST_STRING {
                plist_get_string_val(verNode, &versionString)
                if let version = versionString {
                    iosVersion = String(cString: version)
                    free(version)
                }
            }
            plist_free(verNode)
        }
        
        // Extract serial number
        var serialNode: plist_t? = nil
        if lockdownd_get_value(lockdown, nil, "SerialNumber", &serialNode) == LOCKDOWN_E_SUCCESS,
           let serNode = serialNode {
            var serialString: UnsafeMutablePointer<CChar>? = nil
            if plist_get_node_type(serNode) == PLIST_STRING {
                plist_get_string_val(serNode, &serialString)
                if let serial = serialString {
                    serialNumber = String(cString: serial)
                    free(serial)
                }
            }
            plist_free(serNode)
        }
        
        let deviceInfo = DeviceInfo(
            udid: deviceUDID,
            connectionType: .usb,
            name: deviceName,
            productType: productType,
            iosVersion: iosVersion,
            serialNumber: serialNumber
        )
        
        return DeviceMetadata(
            deviceInfo: deviceInfo,
            rawPlistXML: rawPlistXML,
            rawPlist: nil // Could be parsed if needed
        )
    }
    
    // MARK: - Helper Methods
    
    private func cStringToString(_ cString: UnsafePointer<CChar>?) -> String? {
        guard let cString = cString else { return nil }
        return String(cString: cString)
    }
}
