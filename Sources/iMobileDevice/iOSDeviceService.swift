import Foundation

/// Service class for interacting with iOS devices
public class iOSDeviceService: iOSDeviceServiceType {
    
    private var currentBackupTask: Task<Int, Error>?
    private var isCancelled: Bool = false

    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - iOSDeviceServiceType Implementation
    
    public func listConnectedDevices() async throws -> [iOSDeviceMetadata] {
        var devices: UnsafeMutablePointer<idevice_info_t?>? = nil
        var count: Int32 = 0
        
        let result = idevice_get_device_list_extended(&devices, &count)
        
        guard result == IDEVICE_E_SUCCESS else {
            throw iOSDeviceServiceError.unknown(message: "Failed to get device list. Error code: \(result)")
        }
        
        guard let devicesArray = devices else {
            throw iOSDeviceServiceError.noDevicesFound
        }
        
        var deviceList: [iOSDeviceMetadata] = []
        
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
            
            // Try to enrich basic device info using lockdown, but don't fail the whole list if it fails
            var name: String? = nil
            var deviceClass: String? = nil
            var productType: String? = nil
            var iosVersion: String? = nil
            var serialNumber: String? = nil
            var phoneNumber: String? = nil
            var rawPlistXML: String = ""
            var rawPlistDict: [String: Any]? = nil
            
            var ideviceHandle: idevice_t? = nil
            if idevice_new(&ideviceHandle, udid) == IDEVICE_E_SUCCESS, let dev = ideviceHandle {
                defer { idevice_free(dev) }
                
                var lockdownClient: lockdownd_client_t? = nil
                if lockdownd_client_new_with_handshake(dev, &lockdownClient, "iMobileDevice") == LOCKDOWN_E_SUCCESS,
                   let lockdown = lockdownClient {
                    defer { lockdownd_client_free(lockdown) }
                    
                    // Fetch full device plist
                    if let fullPlist = getLockdownPlist(lockdown, domain: nil, key: nil) {
                        rawPlistXML = fullPlist.rawXML
                        rawPlistDict = fullPlist.dictionary
                    }
                    
                    name = getLockdownString(lockdown, key: "DeviceName")
                    deviceClass = getLockdownString(lockdown, key: "DeviceClass")
                    productType = getLockdownString(lockdown, key: "ProductType")
                    iosVersion = getLockdownString(lockdown, key: "ProductVersion")
                    serialNumber = getLockdownString(lockdown, key: "SerialNumber")
                    phoneNumber = getLockdownString(lockdown, key: "PhoneNumber")
                }
            }
            
            let info = iOSDeviceInfo(
                id: udid,
                connectionType: connectionType,
                name: name,
                deviceClass: deviceClass,
                productType: productType,
                iosVersion: iosVersion,
                serialNumber: serialNumber,
                phoneNumber: phoneNumber
            )
            
            let metadata = iOSDeviceMetadata(
                deviceInfo: info,
                rawPlistXML: rawPlistXML,
                rawPlist: rawPlistDict
            )
            
            deviceList.append(metadata)
        }
        
        // Free the device list
        idevice_device_list_extended_free(devicesArray)
        
        if deviceList.isEmpty {
            throw iOSDeviceServiceError.noDevicesFound
        }
        
        return deviceList
    }
    
    public func getDeviceMetadata(udid: String?) async throws -> iOSDeviceMetadata {
        // Get device UDID
        guard let deviceUDID = udid else {
            throw iOSDeviceServiceError.invalidDeviceId
        }

        // Connect to device
        var device: idevice_t? = nil
        let deviceResult = idevice_new(&device, deviceUDID)
        
        guard deviceResult == IDEVICE_E_SUCCESS, let deviceHandle = device else {
            throw iOSDeviceServiceError.connectionFailed(udid: deviceUDID, code: Int32(deviceResult.rawValue))
        }
        defer { idevice_free(deviceHandle) }
        
        // Create lockdown client
        var lockdownClient: lockdownd_client_t? = nil
        let clientResult = lockdownd_client_new_with_handshake(deviceHandle, &lockdownClient, "iMobileDevice")
        
        guard clientResult == LOCKDOWN_E_SUCCESS, let lockdown = lockdownClient else {
            throw iOSDeviceServiceError.connectionFailed(udid: deviceUDID, code: Int32(clientResult.rawValue))
        }
        defer { lockdownd_client_free(lockdown) }
        
        // Get full device information plist (XML + parsed dict)
        guard let fullPlist = getLockdownPlist(lockdown, domain: nil, key: nil) else {
            throw iOSDeviceServiceError.informationRetrievalFailed(udid: deviceUDID, code: -1)
        }
        
        let rawPlistXML = fullPlist.rawXML
        let dict = fullPlist.dictionary
        
        // Extract structured information using lockdown helpers
        var deviceName: String? = nil
        var productType: String? = nil
        var iosVersion: String? = nil
        var serialNumber: String? = nil
        var deviceClass: String? = nil
        var phoneNumber: String? = nil
        
        deviceName = getLockdownString(lockdown, key: "DeviceName")
        productType = getLockdownString(lockdown, key: "ProductType")
        iosVersion = getLockdownString(lockdown, key: "ProductVersion")
        serialNumber = getLockdownString(lockdown, key: "SerialNumber")
        deviceClass = getLockdownString(lockdown, key: "DeviceClass")
        phoneNumber = getLockdownString(lockdown, key: "PhoneNumber")
        
        let deviceInfo = iOSDeviceInfo(
            id: deviceUDID,
            connectionType: .usb,
            name: deviceName,
            deviceClass: deviceClass,
            productType: productType,
            iosVersion: iosVersion,
            serialNumber: serialNumber,
            phoneNumber: phoneNumber
        )
        
        return iOSDeviceMetadata(
            deviceInfo: deviceInfo,
            rawPlistXML: rawPlistXML,
            rawPlist: dict
        )
    }

    public func createBackup(
        udid: String?,
        backupPath: String,
        forceFull: Bool,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws -> Int {

        currentBackupTask = Task<Int, Error> {
            // Check for cancellation before starting
            try Task.checkCancellation()
            
            // Monitor for cancellation in background
            let cancellationTask = Task {
                while !isCancelled {
                    try? await Task.sleep(nanoseconds: 100_000_000) // Check every 0.1s
                }
                // Task was cancelled, signal C code to stop
                idevicebackup2_cancel()
                isCancelled = false
                return 0
            }
            
            defer {
                cancellationTask.cancel()
            }
            
            // Run the backup
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let result = try self.performBackup(
                            udid: udid,
                            backupPath: backupPath,
                            forceFull: forceFull,
                            progressHandler: progressHandler
                        )
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        defer {
            currentBackupTask = nil
        }
        return try await currentBackupTask?.value ?? 0
    }
    
    private func performBackup(
        udid: String?,
        backupPath: String,
        forceFull: Bool,
        progressHandler: ((Float) -> Void)? = nil
    ) throws -> Int {
        // Validate backup directory
        let fileManager = FileManager.default
        let backupURL = URL(fileURLWithPath: backupPath)
        
        // Create backup directory if it doesn't exist
        if !fileManager.fileExists(atPath: backupPath) {
            do {
                try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw iOSDeviceServiceError.unknown(message: "Failed to create backup directory. Error: \(error)")
            }
        }
        
        // Get device UDID
        guard let deviceUDID = udid else {
            throw iOSDeviceServiceError.invalidDeviceId
        }
        
        // Construct command-line arguments for idevicebackup2_main
        var args = ["idevicebackup2", "-u", deviceUDID, "backup"]
        
        if forceFull {
            args.append("--full")
        }
                
        args.append(backupPath)
        
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
            guard let cString = cString else {
                throw iOSDeviceServiceError.backupFailed(errorCode: -1, message: "Failed to allocate memory for argument")
            }
            cStrings.append(cString)
            argv[index] = cString
        }
        argv[args.count] = nil // NULL terminator
        
        // NEW: Setup progress callback if provided
        var handler: BackupProgressHandler?
        var userdata: UnsafeMutableRawPointer?
        if let progressHandler = progressHandler {
            handler = BackupProgressHandler(progressClosure: progressHandler)
            userdata = Unmanaged.passUnretained(handler!).toOpaque()
        }

        // Call the main function directly from idevicebackup2.c
        let result = idevicebackup2_main(
            argc,
            argv,
            handler != nil ? BackupProgressHandler.cCallback : nil,
            userdata
        )
        
        // Keep handler alive until function returns
        withExtendedLifetime(handler) {
            // Handler stays alive during the C call
        }

        if result == 0 {
            // Success - count files in backup directory
            let fileCount = countFilesInBackup(backupPath: backupPath, udid: deviceUDID)
            return fileCount
        } else {
            throw iOSDeviceServiceError.backupFailed(errorCode: Int(result), message: "Backup process failed with code \(result)")
        }
    }
    
    // Allow cancellation
    public func cancelBackup() {
        currentBackupTask?.cancel()
        isCancelled = true
    }
}

// MARK: - Helper Methods
extension iOSDeviceService {
    
    private func cStringToString(
        _ cString: UnsafePointer<CChar>?
    ) -> String? {
        guard let cString = cString else { return nil }
        return String(cString: cString)
    }
    
    // Convenience helper to fetch a string value from lockdown without throwing.
    private func getLockdownString(
        _ client: lockdownd_client_t,
        key: String
    ) -> String? {
        var node: plist_t? = nil
        
        let result = key.withCString { keyC in
            lockdownd_get_value(client, nil, keyC, &node)
        }
        
        guard result == LOCKDOWN_E_SUCCESS, let valueNode = node else {
            return nil
        }
        defer { plist_free(valueNode) }
        
        guard plist_get_node_type(valueNode) == PLIST_STRING else {
            return nil
        }
        
        var stringValue: UnsafeMutablePointer<CChar>? = nil
        plist_get_string_val(valueNode, &stringValue)
        
        guard let str = stringValue else {
            return nil
        }
        defer { free(str) }
        
        return String(cString: str)
    }
    
    /// Convenience helper to fetch the full lockdown plist (XML + parsed dict) without throwing.
    private func getLockdownPlist(
        _ client: lockdownd_client_t,
        domain: UnsafePointer<CChar>?,
        key: UnsafePointer<CChar>?
    ) -> (rawXML: String, dictionary: [String: Any]?)? {
        var plistNode: plist_t? = nil
        let result = lockdownd_get_value(client, domain, key, &plistNode)
        
        guard result == LOCKDOWN_E_SUCCESS, let plist = plistNode else {
            return nil
        }
        defer { plist_free(plist) }
        
        var xmlPtr: UnsafeMutablePointer<CChar>? = nil
        var length: UInt32 = 0
        plist_to_xml(plist, &xmlPtr, &length)
        guard let xml = xmlPtr else {
            return nil
        }
        defer { free(xml) }
        
        let rawXML = String(cString: xml)
        let data = rawXML.data(using: .utf8)
        let dict = (try? PropertyListSerialization.propertyList(from: data ?? Data(), format: nil)) as? [String: Any]
        
        return (rawXML, dict)
    }

    private func countFilesInBackup(backupPath: String, udid: String) -> Int {
        let fileManager = FileManager.default
        let deviceBackupPath = (backupPath as NSString).appendingPathComponent(udid)
        
        guard let enumerator = fileManager.enumerator(atPath: deviceBackupPath) else {
            return 0
        }
        
        var count = 0
        while enumerator.nextObject() != nil {
            count += 1
        }
        
        return count
    }
}

// MARK: - C Function Declaration

/// Progress callback type matching C: void (*)(float, void*)
typealias ProgressCallback = @convention(c) (Float, UnsafeMutableRawPointer?) -> Void

/// Direct call to main() from idevicebackup2.c (renamed to idevicebackup2_main)
/// Now includes progress_callback and callback_userdata parameters
@_silgen_name("idevicebackup2_main")
private func idevicebackup2_main(
    _ argc: Int32,
    _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
    _ progress_callback: ProgressCallback?,
    _ callback_userdata: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("idevicebackup2_cancel")
private func idevicebackup2_cancel()

// MARK: - Progress Handler

class BackupProgressHandler {
    typealias ProgressClosure = (Float) -> Void
    
    private var progressClosure: ProgressClosure?
    
    init(progressClosure: @escaping ProgressClosure) {
        self.progressClosure = progressClosure
    }
    
    // This is the C callback that will be called from the C code
    static let cCallback: ProgressCallback = { (progress, userdata) in
        guard let userdata = userdata else { return }
        
        // Convert the raw pointer back to our handler
        let handler = Unmanaged<BackupProgressHandler>.fromOpaque(userdata).takeUnretainedValue()
        
        // Call the Swift closure
        handler.progressClosure?(progress)
    }
}
