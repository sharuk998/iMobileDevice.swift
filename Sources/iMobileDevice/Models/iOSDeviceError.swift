//
//  iOSDeviceError.swift
//  ReconCore
//
//  Created by Shahrukh on 26/01/2026.
//

import Foundation

enum iOSDeviceError: Error, LocalizedError {
    case noDevicesFound
    case invalidPropertyList
    case backupFailed(errorCode: Int?, message: String)
    case backupAborted
    case connectionFailed(udid: String, code: Int32)
    case informationRetrievalFailed(udid: String, code: Int32)
    case unknown(message: String)
    
    var errorDescription: String? {
        switch self {
        case .noDevicesFound:
            return "No devices found"
        case .invalidPropertyList:
            return "Invalid property list format"
        case .backupFailed(let errorCode, let message):
            if let errorCode = errorCode {
                return "Backup failed with error code \(errorCode): \(message)"
            }
            return "Backup failed: \(message)"
        case .backupAborted:
            return "Backup was aborted"
        case let .connectionFailed(uuid, code):
            return "Error (\(code)): Failed to connect to \(uuid)."
        case let .informationRetrievalFailed(uuid, code):
            return "Error (\(code)): Failed to retrieve information for \(uuid)."
        case .unknown(let message):
            return message
        }
    }
}
