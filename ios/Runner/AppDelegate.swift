import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let fileChannel = FlutterMethodChannel(
      name: "jizhang/file_opener",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    fileChannel.setMethodCallHandler { call, result in
      guard call.method == "openFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let path = arguments["path"] as? String,
            !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        result(FlutterError(code: "INVALID_FILE_PATH", message: "Attachment path is empty", details: nil))
        return
      }
      let fileURL = URL(fileURLWithPath: path)
      let resolvedFileURL = fileURL.resolvingSymlinksInPath().standardizedFileURL
      let standardizedPath = resolvedFileURL.path
      let fileManager = FileManager.default
      let allowedRoots = [
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
          .first,
      ].compactMap { $0?.standardizedFileURL.path }
      guard allowedRoots.contains(where: { root in
        standardizedPath == root || standardizedPath.hasPrefix(root + "/")
      }) else {
        result(FlutterError(code: "INVALID_FILE_PATH", message: "Attachment is outside the app storage scope", details: nil))
        return
      }
      var isDirectory: ObjCBool = false
      guard fileManager.fileExists(
        atPath: standardizedPath,
        isDirectory: &isDirectory
      ), !isDirectory.boolValue else {
        result(FlutterError(code: "FILE_NOT_FOUND", message: "Attachment file does not exist", details: nil))
        return
      }
      DispatchQueue.main.async {
        UIApplication.shared.open(resolvedFileURL, options: [:]) { opened in
          if opened {
            result(true)
          } else {
            result(FlutterError(code: "NO_HANDLER", message: "No application can open this file", details: nil))
          }
        }
      }
    }
  }
}
