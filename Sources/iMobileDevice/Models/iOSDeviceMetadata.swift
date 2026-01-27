//
//  iOSDeviceMetadata.swift
//  ReconCore
//
//  Created by Shahrukh on 26/01/2026.
//

import Foundation

/// Complete device metadata including raw plist data
public struct iOSDeviceMetadata {
    /// Structured device information
    public let deviceInfo: iOSDeviceInfo
    
    /// Raw plist as string
    public let rawPlistXML: String

    /// Raw plist dictionary (if parsed)
    public let rawPlist: [String: Any]?
    
    public init(
        deviceInfo: iOSDeviceInfo,
        rawPlistXML: String,
        rawPlist: [String: Any]? = nil
    ) {
        self.deviceInfo = deviceInfo
        self.rawPlistXML = rawPlistXML
        self.rawPlist = rawPlist
    }
}
