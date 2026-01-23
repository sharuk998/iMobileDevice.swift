import Foundation

// MARK: - Usage Examples
// This file demonstrates how to use the iOSDeviceService

/*
 Example 1: List all connected devices
 
 let service = iOSDeviceService()
 
 do {
     let devices = try service.listConnectedDevices()
     for device in devices {
         print("Device: \(device.name ?? "Unknown")")
         print("  UDID: \(device.udid)")
         print("  Connection: \(device.connectionType.rawValue)")
     }
 } catch {
     print("Error: \(error)")
 }
 
 Example 2: Get device metadata (with raw plist)
 
 let service = iOSDeviceService()
 
 do {
     let metadata = try service.getDeviceMetadata(udid: nil) // nil = first device
     print("Device Name: \(metadata.deviceInfo.name ?? "Unknown")")
     print("Product Type: \(metadata.deviceInfo.productType ?? "Unknown")")
     print("iOS Version: \(metadata.deviceInfo.iosVersion ?? "Unknown")")
     print("Serial Number: \(metadata.deviceInfo.serialNumber ?? "Unknown")")
     print("\nRaw Plist XML:")
     print(metadata.rawPlistXML)
 } catch {
     print("Error: \(error)")
 }
 
 Example 3: Create a backup
 
 let service = iOSDeviceService()
 
 do {
     let fileCount = try service.createBackup(
         udid: nil, // nil = first device
         backupPath: "./backup",
         password: nil, // nil = unencrypted backup
         forceFull: true
     )
     print("Backup completed! Files backed up: \(fileCount)")
 } catch DeviceServiceError.backupFailed(let udid, let code, let message) {
     print("Backup failed for device \(udid): \(message ?? "Unknown error")")
 } catch {
     print("Error: \(error)")
 }
 
 Example 4: Using individual services (for dependency injection)
 
 let deviceService = DeviceService()
 let backupService = BackupService(deviceService: deviceService)
 
 // Use device service
 let devices = try deviceService.listConnectedDevices()
 let metadata = try deviceService.getDeviceMetadata(udid: devices.first?.udid)
 
 // Use backup service
 let fileCount = try backupService.createBackup(
     udid: devices.first?.udid,
     backupPath: "./backup",
     password: nil,
     forceFull: true
 )
 
 Example 5: Custom service implementation (for testing)
 
 class MockDeviceService: DeviceServiceProtocol {
     func listConnectedDevices() throws -> [DeviceInfo] {
         return [DeviceInfo(udid: "test-udid", connectionType: .usb, name: "Test Device")]
     }
     
     func getDeviceMetadata(udid: String?) throws -> DeviceMetadata {
         let device = DeviceInfo(udid: "test-udid", connectionType: .usb, name: "Test Device")
         return DeviceMetadata(deviceInfo: device, rawPlistXML: "<plist></plist>")
     }
 }
 
 let mockService = MockDeviceService()
 let backupService = BackupService(deviceService: mockService)
 */
