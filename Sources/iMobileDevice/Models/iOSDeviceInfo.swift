//
//  iOSDeviceInfo.swift
//  ReconCore
//
//  Created by Shahrukh on 26/01/2026.
//

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
public struct iOSDeviceInfo: Codable, Identifiable, Equatable {
    /// Unique Device Identifier - UniqueDeviceID
    public let id: String
    
    /// Connection type (USB or Network)
    public let connectionType: DeviceConnectionType
    
    /// DeviceName ("iPhone S")
    public let name: String?
    
    /// DeviceClass (iPhone, iPad)
    public let deviceClass: String?
    
    /// ProductType (e.g., "iPhone9,3")
    public let productType: String?
    
    /// iOS version (e.g., "15.8.4") - ProductVersion
    public let iosVersion: String?
    
    /// SerialNumber
    public let serialNumber: String?
        
    /// PhoneNumber
    public let phoneNumber: String?
    
    public init(
        id: String,
        connectionType: DeviceConnectionType,
        name: String? = nil,
        deviceClass: String? = nil,
        productType: String? = nil,
        iosVersion: String? = nil,
        serialNumber: String? = nil,
        phoneNumber: String? = nil
    ) {
        self.id = id
        self.connectionType = connectionType
        self.name = name
        self.deviceClass = deviceClass
        self.productType = productType
        self.iosVersion = iosVersion
        self.serialNumber = serialNumber
        self.phoneNumber = phoneNumber
    }
}
