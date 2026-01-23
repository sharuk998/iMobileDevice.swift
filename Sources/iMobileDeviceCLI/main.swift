import Foundation
import iMobileDevice

// Helper function to convert C string to Swift String
func cStringToString(_ cString: UnsafePointer<CChar>?) -> String? {
    guard let cString = cString else { return nil }
    return String(cString: cString)
}

// Helper function to print plist as XML
func printPlist(_ plist: plist_t?) {
    guard let plist = plist else {
        print("  (null)")
        return
    }
    
    var xmlString: UnsafeMutablePointer<CChar>? = nil
    var length: UInt32 = 0
    plist_to_xml(plist, &xmlString, &length)
    
    if let xmlString = xmlString {
        if let xml = String(cString: xmlString, encoding: .utf8) {
            print("  \(xml)")
        }
        free(xmlString)
    }
}

// MARK: - List Connected iOS Devices
func listConnectedDevices() {
    print("=== Listing Connected iOS Devices ===\n")
    
    var devices: UnsafeMutablePointer<idevice_info_t?>? = nil
    var count: Int32 = 0
    
    let result = idevice_get_device_list_extended(&devices, &count)
    
    if result != IDEVICE_E_SUCCESS {
        print("Error: Failed to get device list (error code: \(result))")
        return
    }
    
    guard let devicesArray = devices else {
        return
    }
    
    if count == 0 {
        print("No devices found. Please connect an iOS device via USB.")
        idevice_device_list_extended_free(devicesArray)
        return
    }
    
    print("Found \(count) device(s):\n")
    
    var i = 0
    while i < Int(count), let devicePtr = devicesArray[i] {
        let udid = cStringToString(devicePtr.pointee.udid) ?? "Unknown"
        let connType = devicePtr.pointee.conn_type == CONNECTION_USBMUXD ? "USB" : "Network"
        
        print("Device \(i + 1):")
        print("  UDID: \(udid)")
        print("  Connection: \(connType)")
        print()
        
        i += 1
    }
    
    idevice_device_list_extended_free(devicesArray)
}

// MARK: - Print Device Information
func printDeviceInfo(udid: String? = nil) {
    print("=== Device Information ===\n")
    
    var device: idevice_t? = nil
    var deviceUDID: String
    
    // If no UDID provided, get the first device
    if let udid = udid {
        deviceUDID = udid
    } else {
        var devices: UnsafeMutablePointer<idevice_info_t?>? = nil
        var count: Int32 = 0
        
        let result = idevice_get_device_list_extended(&devices, &count)
        if result != IDEVICE_E_SUCCESS || count == 0 {
            print("Error: No devices found")
            return
        }
        
        guard let devicesArray = devices else {
            print("Error: Could not get device list")
            return
        }
        
        if count > 0, let firstDevice = devicesArray[0] {
            deviceUDID = cStringToString(firstDevice.pointee.udid) ?? ""
        } else {
            print("Error: Could not get device UDID")
            idevice_device_list_extended_free(devicesArray)
            return
        }
        
        // Free the device list after extracting UDID
        idevice_device_list_extended_free(devicesArray)
        
        if deviceUDID.isEmpty {
            print("Error: Could not get device UDID")
            return
        }
    }
    
    print("Connecting to device: \(deviceUDID)\n")
    
    // Create device connection
    let options = idevice_options(rawValue: IDEVICE_LOOKUP_USBMUX.rawValue | IDEVICE_LOOKUP_NETWORK.rawValue)
    let deviceResult = idevice_new_with_options(&device, deviceUDID, options)
    if deviceResult != IDEVICE_E_SUCCESS {
        print("Error: Failed to connect to device (error code: \(deviceResult))")
        return
    }
    
    // Create lockdown client
    var lockdownClient: lockdownd_client_t? = nil
    let lockdownResult = lockdownd_client_new_with_handshake(device, &lockdownClient, "iMobileDeviceCLI")
    
    if lockdownResult != LOCKDOWN_E_SUCCESS {
        print("Error: Failed to create lockdown client (error code: \(lockdownResult))")
        if lockdownResult == LOCKDOWN_E_PAIRING_FAILED {
            print("Note: Device may need to be paired first. Try running the pair function.")
        }
        idevice_free(device)
        return
    }
    
    print("Device Information:\n")
    
    // Get device name
    var deviceName: UnsafeMutablePointer<CChar>? = nil
    if lockdownd_get_device_name(lockdownClient, &deviceName) == LOCKDOWN_E_SUCCESS {
        if let name = cStringToString(deviceName) {
            print("  Name: \(name)")
        }
        free(deviceName)
    }
    
    // Get device info (all values)
    var deviceInfo: plist_t? = nil
    if lockdownd_get_value(lockdownClient, nil, nil, &deviceInfo) == LOCKDOWN_E_SUCCESS {
        print("\n  Full Device Info:")
        printPlist(deviceInfo)
        plist_free(deviceInfo)
    }
    
    // Get specific values
    var value: plist_t? = nil
    
    if lockdownd_get_value(lockdownClient, nil, "ProductType", &value) == LOCKDOWN_E_SUCCESS {
        var productType: UnsafeMutablePointer<CChar>? = nil
        plist_get_string_val(value, &productType)
        if let type = cStringToString(productType) {
            print("\n  Product Type: \(type)")
        }
        plist_free(value)
    }
    
    if lockdownd_get_value(lockdownClient, nil, "ProductVersion", &value) == LOCKDOWN_E_SUCCESS {
        var version: UnsafeMutablePointer<CChar>? = nil
        plist_get_string_val(value, &version)
        if let ver = cStringToString(version) {
            print("  iOS Version: \(ver)")
        }
        plist_free(value)
    }
    
    if lockdownd_get_value(lockdownClient, nil, "SerialNumber", &value) == LOCKDOWN_E_SUCCESS {
        var serial: UnsafeMutablePointer<CChar>? = nil
        plist_get_string_val(value, &serial)
        if let sn = cStringToString(serial) {
            print("  Serial Number: \(sn)")
        }
        plist_free(value)
    }
    
    if lockdownd_get_value(lockdownClient, nil, "UniqueDeviceID", &value) == LOCKDOWN_E_SUCCESS {
        var udid: UnsafeMutablePointer<CChar>? = nil
        plist_get_string_val(value, &udid)
        if let id = cStringToString(udid) {
            print("  UDID: \(id)")
        }
        plist_free(value)
    }
    
    // Cleanup
    lockdownd_client_free(lockdownClient)
    idevice_free(device)
    
    print()
}

// MARK: - Pair with Device
func pairWithDevice(udid: String? = nil) {
    print("=== Pairing with Device ===\n")
    
    var device: idevice_t? = nil
    var deviceUDID: String
    
    // If no UDID provided, get the first device
    if let udid = udid {
        deviceUDID = udid
    } else {
        var devices: UnsafeMutablePointer<idevice_info_t?>? = nil
        var count: Int32 = 0
        
        let result = idevice_get_device_list_extended(&devices, &count)
        if result != IDEVICE_E_SUCCESS || count == 0 {
            print("Error: No devices found")
            return
        }
        
        guard let devicesArray = devices else {
            print("Error: Could not get device list")
            return
        }
        
        if count > 0, let firstDevice = devicesArray[0] {
            deviceUDID = cStringToString(firstDevice.pointee.udid) ?? ""
        } else {
            print("Error: Could not get device UDID")
            idevice_device_list_extended_free(devicesArray)
            return
        }
        
        // Free the device list after extracting UDID
        idevice_device_list_extended_free(devicesArray)
        
        if deviceUDID.isEmpty {
            print("Error: Could not get device UDID")
            return
        }
    }
    
    print("Pairing with device: \(deviceUDID)\n")
    
    // Create device connection
    let options = idevice_options(rawValue: IDEVICE_LOOKUP_USBMUX.rawValue | IDEVICE_LOOKUP_NETWORK.rawValue)
    let deviceResult = idevice_new_with_options(&device, deviceUDID, options)
    if deviceResult != IDEVICE_E_SUCCESS {
        print("Error: Failed to connect to device (error code: \(deviceResult))")
        return
    }
    
    // Create lockdown client (without handshake first)
    var lockdownClient: lockdownd_client_t? = nil
    let clientResult = lockdownd_client_new(device, &lockdownClient, "iMobileDeviceCLI")
    
    if clientResult != LOCKDOWN_E_SUCCESS {
        print("Error: Failed to create lockdown client (error code: \(clientResult))")
        idevice_free(device)
        return
    }
    
    // Check if already paired
    let validateResult = lockdownd_validate_pair(lockdownClient, nil)
    if validateResult == LOCKDOWN_E_SUCCESS {
        print("Device is already paired!")
        lockdownd_client_free(lockdownClient)
        idevice_free(device)
        return
    }
    
    // Attempt to pair
    print("Attempting to pair...")
    print("Note: You may need to trust this computer on your iOS device.")
    print("Please check your device and tap 'Trust' if prompted.\n")
    
    var pairResult = lockdownd_pair(lockdownClient, nil)
    
    // If pairing dialog is pending, wait for user response
    if pairResult == LOCKDOWN_E_PAIRING_DIALOG_RESPONSE_PENDING {
        print("Waiting for user to respond on device...")
        print("(This may take up to 30 seconds)")
        
        // Poll for pairing completion
        var attempts = 0
        let maxAttempts = 30 // 30 seconds
        
        while attempts < maxAttempts {
            Thread.sleep(forTimeInterval: 1.0)
            pairResult = lockdownd_validate_pair(lockdownClient, nil)
            
            if pairResult == LOCKDOWN_E_SUCCESS {
                print("\n✓ Pairing successful!")
                break
            }
            
            attempts += 1
            if attempts % 5 == 0 {
                print(".", terminator: "")
                fflush(stdout)
            }
        }
        
        if pairResult != LOCKDOWN_E_SUCCESS {
            print("\n✗ Pairing timed out or failed")
        }
    } else if pairResult == LOCKDOWN_E_SUCCESS {
        print("✓ Pairing successful!")
    } else {
        print("✗ Pairing failed (error code: \(pairResult))")
        
        switch pairResult {
        case LOCKDOWN_E_PASSWORD_PROTECTED:
            print("  Device is password protected. Please unlock your device and try again.")
        case LOCKDOWN_E_USER_DENIED_PAIRING:
            print("  User denied pairing on the device.")
        default:
            print("  Please check that the device is unlocked and you trust this computer.")
        }
    }
    
    // Cleanup
    lockdownd_client_free(lockdownClient)
    idevice_free(device)
    
    print()
}

// MARK: - Create iOS Backup
func createBackup(udid: String? = nil, backupPath: String = "./backup") {
    print("=== Creating iOS Backup ===\n")
    
    var device: idevice_t? = nil
    var deviceUDID: String
    
    // If no UDID provided, get the first device
    if let udid = udid {
        deviceUDID = udid
    } else {
        var devices: UnsafeMutablePointer<idevice_info_t?>? = nil
        var count: Int32 = 0
        
        let result = idevice_get_device_list_extended(&devices, &count)
        if result != IDEVICE_E_SUCCESS || count == 0 {
            print("Error: No devices found")
            return
        }
        
        guard let devicesArray = devices else {
            print("Error: Could not get device list")
            return
        }
        
        if count > 0, let firstDevice = devicesArray[0] {
            deviceUDID = cStringToString(firstDevice.pointee.udid) ?? ""
        } else {
            print("Error: Could not get device UDID")
            idevice_device_list_extended_free(devicesArray)
            return
        }
        
        // Free the device list after extracting UDID
        idevice_device_list_extended_free(devicesArray)
        
        if deviceUDID.isEmpty {
            print("Error: Could not get device UDID")
            return
        }
    }
    
    print("Creating backup for device: \(deviceUDID)")
    print("Backup path: \(backupPath)\n")
    
    // Create backup directory
    let fileManager = FileManager.default
    let backupURL = URL(fileURLWithPath: backupPath)
    
    do {
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true, attributes: nil)
        print("✓ Backup directory created: \(backupPath)\n")
    } catch {
        print("Error: Failed to create backup directory: \(error)")
        return
    }
    
    // Create device connection
    let options = idevice_options(rawValue: IDEVICE_LOOKUP_USBMUX.rawValue | IDEVICE_LOOKUP_NETWORK.rawValue)
    let deviceResult = idevice_new_with_options(&device, deviceUDID, options)
    if deviceResult != IDEVICE_E_SUCCESS {
        print("Error: Failed to connect to device (error code: \(deviceResult))")
        return
    }
    
    // Create lockdown client
    var lockdownClient: lockdownd_client_t? = nil
    let lockdownResult = lockdownd_client_new_with_handshake(device, &lockdownClient, "iMobileDeviceCLI")
    
    if lockdownResult != LOCKDOWN_E_SUCCESS {
        print("Error: Failed to create lockdown client (error code: \(lockdownResult))")
        if lockdownResult == LOCKDOWN_E_PAIRING_FAILED {
            print("Note: Device must be paired first. Run the pair function.")
        }
        idevice_free(device)
        return
    }
    
    // Start mobilebackup2 service
    var service: lockdownd_service_descriptor_t? = nil
    let serviceResult = lockdownd_start_service(lockdownClient, MOBILEBACKUP2_SERVICE_NAME, &service)
    
    if serviceResult != LOCKDOWN_E_SUCCESS {
        print("Error: Failed to start mobilebackup2 service (error code: \(serviceResult))")
        lockdownd_client_free(lockdownClient)
        idevice_free(device)
        return
    }
    
    // Create mobilebackup2 client
    var backupClient: mobilebackup2_client_t? = nil
    let backupClientResult = mobilebackup2_client_new(device, service, &backupClient)
    
    if backupClientResult != MOBILEBACKUP2_E_SUCCESS {
        print("Error: Failed to create mobilebackup2 client (error code: \(backupClientResult))")
        lockdownd_client_free(lockdownClient)
        idevice_free(device)
        return
    }
    
    print("Connected to mobilebackup2 service")
    print("Starting backup process...\n")
    
    // Perform version exchange
    var localVersions: [Double] = [2.0, 2.1]
    var remoteVersion: Double = 0.0
    let versionResult = mobilebackup2_version_exchange(backupClient, &localVersions, 2, &remoteVersion)
    
    if versionResult != MOBILEBACKUP2_E_SUCCESS {
        print("Error: Version exchange failed (error code: \(versionResult))")
        mobilebackup2_client_free(backupClient)
        lockdownd_client_free(lockdownClient)
        idevice_free(device)
        return
    }
    
    print("Protocol version: \(remoteVersion)\n")
    
    // Create backup options (for full backup, we can pass NULL or ForceFullBackup option)
    // For a full backup, source_identifier should be the same as target_identifier
    let backupOptions = plist_new_dict()
    // Force full backup (optional - empty dict also works for full backup)
    plist_dict_set_item(backupOptions, "ForceFullBackup", plist_new_bool(1))
    
    // Send backup request
    // Parameters: client, "Backup", target_UDID, source_UDID, options
    // For full backup: source_UDID = target_UDID (same device)
    // For incremental: source_UDID = UDID of previous backup
    let requestResult = mobilebackup2_send_request(backupClient, "Backup", deviceUDID, deviceUDID, backupOptions)
    
    if requestResult != MOBILEBACKUP2_E_SUCCESS {
        print("Error: Failed to send backup request (error code: \(requestResult))")
        if requestResult == MOBILEBACKUP2_E_REPLY_NOT_OK {
            print("  Device refused the backup request. Device may need to be unlocked or paired.")
        }
        plist_free(backupOptions)
        mobilebackup2_client_free(backupClient)
        lockdownd_client_free(lockdownClient)
        idevice_free(device)
        return
    }
    
    plist_free(backupOptions)
    
    print("Backup request sent. Waiting for device response...")
    print("This may take several minutes depending on device data size.\n")
    
    // Receive and process backup messages
    var backupComplete = false
    var fileCount = 0
    var lastProgressUpdate = Date()
    let startTime = Date()
    let maxBackupTime: TimeInterval = 300 // 5 minutes max
    
    while !backupComplete {
        // Check for timeout
        if Date().timeIntervalSince(startTime) > maxBackupTime {
            print("\n⚠️  Backup timeout after 5 minutes")
            print("   The backup protocol is not completing. This may be because:")
            print("   1. The device is sending unexpected messages")
            print("   2. File receiving is not implemented (files are not being written to disk)")
            print("   3. The backup request parameters may be incorrect")
            break
        }
        var msgPlist: plist_t? = nil
        var dlMessage: UnsafeMutablePointer<CChar>? = nil
        
        let receiveResult = mobilebackup2_receive_message(backupClient, &msgPlist, &dlMessage)
        
        if receiveResult != MOBILEBACKUP2_E_SUCCESS {
            if receiveResult == MOBILEBACKUP2_E_RECEIVE_TIMEOUT {
                // Timeout is normal, continue waiting
                // Show progress indicator every 5 seconds
                let now = Date()
                if now.timeIntervalSince(lastProgressUpdate) >= 5.0 {
                    print("  Waiting for backup data... (processed \(fileCount) files so far)")
                    lastProgressUpdate = now
                }
                Thread.sleep(forTimeInterval: 0.5)
                continue
            } else {
                print("Error receiving backup message (error code: \(receiveResult))")
                break
            }
        }
        
        guard let message = dlMessage else {
            if let plist = msgPlist {
                plist_free(plist)
            }
            continue
        }
        
        let messageStr = cStringToString(message) ?? ""
        
        if messageStr == "DLMessageUploadFiles" {
            // Device wants to upload files (backup) - this is what we want!
            print("  Receiving backup files from device...")
            
            // Send status response to acknowledge we're ready to receive
            let emptyDict = plist_new_dict()
            let statusResult = mobilebackup2_send_status_response(backupClient, 0, nil, emptyDict)
            plist_free(emptyDict)
            
            if statusResult != MOBILEBACKUP2_E_SUCCESS {
                print("  Error sending status response: \(statusResult)")
                free(message)
                if let plist = msgPlist {
                    plist_free(plist)
                }
                continue
            }
            
            // Note: Full implementation would receive files here using mobilebackup2_receive_raw()
            // and write them to disk. For now, we acknowledge and the device will continue.
            print("  Acknowledged file upload request")
            fileCount += 1
            
            if let plist = msgPlist {
                plist_free(plist)
            }
            
        } else if messageStr == "DLMessageDownloadFiles" {
            // Device wants to download files (restore) - unexpected for backup
            print("  ⚠️  Device requested file download (restore mode) during backup")
            print("     This is the WRONG direction - device should upload files for backup")
            print("     The backup request may not have been processed correctly by the device")
            print("     Attempting to continue, but backup will likely not work...")
            // Send empty status response to continue (though this won't help)
            let emptyDict = plist_new_dict()
            mobilebackup2_send_status_response(backupClient, 0, nil, emptyDict)
            plist_free(emptyDict)
            
            // After receiving DownloadFiles, the device expects us to send files
            // Since we're doing backup, we should break here
            print("  Breaking backup loop - device is in restore mode, not backup mode")
            backupComplete = true
            
        } else if messageStr == "DLMessageGetFreeDiskSpace" {
            // Device wants to know available disk space
            let fm = FileManager.default
            if let stat = try? fm.attributesOfFileSystem(forPath: backupPath) {
                if let freeSpace = stat[FileAttributeKey.systemFreeSize] as? UInt64 {
                    let freeSpaceItem = plist_new_uint(freeSpace)
                    mobilebackup2_send_status_response(backupClient, 0, nil, freeSpaceItem)
                    plist_free(freeSpaceItem)
                } else {
                    let emptyDict = plist_new_dict()
                    mobilebackup2_send_status_response(backupClient, 0, nil, emptyDict)
                    plist_free(emptyDict)
                }
            } else {
                let emptyDict = plist_new_dict()
                mobilebackup2_send_status_response(backupClient, 0, nil, emptyDict)
                plist_free(emptyDict)
            }
            
        } else if messageStr.contains("BackupComplete") || messageStr.contains("DLMessageBackupComplete") {
            backupComplete = true
            print("\n✓ Backup completed successfully!")
            
        } else if messageStr.contains("ErrorDomain") || messageStr.contains("DLMessageError") {
            backupComplete = true
            print("\n✗ Backup failed: \(messageStr)")
            
        } else {
            // Unknown message - send status response to continue
            print("  Received: \(messageStr)")
            let emptyDict = plist_new_dict()
            mobilebackup2_send_status_response(backupClient, 0, nil, emptyDict)
            plist_free(emptyDict)
        }
        
        free(message)
        
        if let plist = msgPlist, messageStr != "DLMessageUploadFiles" {
            // Free plist if we haven't already processed it
            plist_free(plist)
        }
    }
    
    if !backupComplete {
        print("\n⚠️  Backup process did not complete normally.")
        print("   The device may have sent unexpected messages or the backup was interrupted.")
    }
    
    print("\nBackup process completed. Total operations: \(fileCount)")
    print("Backup location: \(backupPath)")
    print("\n⚠️  NOTE: This is a simplified backup implementation.")
    print("   It handles the backup protocol messages but does NOT actually receive")
    print("   and write files to disk. For a complete backup, you would need to:")
    print("   1. Receive DLMessageUploadFiles")
    print("   2. Parse the file list from the plist")
    print("   3. Use mobilebackup2_receive_raw() to receive each file's data")
    print("   4. Write files to disk in the backup directory")
    print("   5. Send status responses after each file")
    print("   6. Continue until DLMessageBackupComplete is received")
    
    // Cleanup
    mobilebackup2_client_free(backupClient)
    lockdownd_client_free(lockdownClient)
    idevice_free(device)
    
    print()
}

// MARK: - Main
func main() {
    print("iMobileDevice CLI Tool\n")
    print("======================\n")
    
    // List connected devices
    listConnectedDevices()
    
    // Print device information
    printDeviceInfo()
    
    // Pair with device
    pairWithDevice()
    
    // Create backup
    createBackup()
    
    print("All operations completed!")
}

main()
