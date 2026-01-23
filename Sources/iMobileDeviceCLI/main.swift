import Foundation
import iMobileDevice

// Directly call main() from idevicebackup2.c (renamed to idevicebackup2_main)
@_silgen_name("idevicebackup2_main")
func idevicebackup2_main(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

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
        case LOCKDOWN_E_PAIRING_FAILED:
            print("  Pairing failed. Try using the system tool:")
            print("    $ idevicepair pair")
            print("  Then tap 'Trust' on your device when prompted.")
        default:
            print("  Please check that the device is unlocked and you trust this computer.")
            print("  You can also try using the system tool:")
            print("    $ idevicepair pair")
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
    
    var deviceUDID: String = ""
    
    // Get device UDID
    if let providedUDID = udid {
        deviceUDID = providedUDID
    } else {
        // Get first connected device
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
            return
        }
        
        // Get UDID from first device
        if let devicePtr = devicesArray[0] {
            deviceUDID = cStringToString(devicePtr.pointee.udid) ?? ""
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
    
    print("Starting backup process...")
    print("⚠️  If your device asks for a passcode, please enter it on the device now.")
    print("This may take several minutes depending on device data size.\n")
    
    // Directly call main() from idevicebackup2.c with constructed argc/argv
    // This is the simplest approach - just use the original code as-is!
    let args = ["idevicebackup2", "-u", deviceUDID, "backup", "--full", backupPath]
    
    // Allocate memory for argv array
    let argc = Int32(args.count)
    let argv = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: args.count + 1)
    defer { argv.deallocate() }
    
    // Allocate memory for each argument string
    var cStrings: [UnsafeMutablePointer<CChar>] = []
    defer {
        for cString in cStrings {
            cString.deallocate()
        }
    }
    
    for (index, arg) in args.enumerated() {
        let cString = strdup(arg)
        cStrings.append(cString!)
        argv[index] = cString
    }
    argv[args.count] = nil // NULL terminator
    
    // Call the main function directly from idevicebackup2.c
    let result = idevicebackup2_main(argc, argv)
    
    if result == 0 {
        print("\n✓ Backup completed successfully!")
        print("  Backup location: \(backupPath)")
    } else {
        print("\n✗ Backup failed with exit code: \(result)")
        print("  Please check device connection and pairing status.")
    }
    
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
