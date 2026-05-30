import UIKit
import Flutter

class StorageUtils: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.audionotes/storage", binaryMessenger: registrar.messenger())
        let instance = StorageUtils()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getFreeBytes":
            let freeBytes = getFreeStorageSpace()
            result(freeBytes)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getFreeStorageSpace() -> Int64 {
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return 100 * 1024 * 1024 // Fallback 100MB
        }
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: documentsPath.path)
            let freeSpace = attributes[.systemFreeSize] as? Int64 ?? 100 * 1024 * 1024
            return freeSpace
        } catch {
            return 100 * 1024 * 1024 // Fallback 100MB
        }
    }
}