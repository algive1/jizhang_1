import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UNUserNotificationCenterDelegate {
  private var navigationChannel: FlutterMethodChannel?
  private var pendingNotificationRoute: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    navigationChannel = FlutterMethodChannel(
      name: "jizhang/navigation",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    if let route = pendingNotificationRoute {
      pendingNotificationRoute = nil
      emitNotificationRoute(route)
    }

    let appUpdateChannel = FlutterMethodChannel(
      name: "jizhang/app_update",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    appUpdateChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "appInfo":
        let version =
          Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0.0.0"
        let build =
          Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
            as? String ?? "0"
        result([
          "platform": "ios",
          "version": version,
          "build": Int(build) ?? 0,
        ])
      case "openStore":
        guard let arguments = call.arguments as? [String: Any],
              let rawUrl = arguments["url"] as? String,
              let url = URL(string: rawUrl),
              url.scheme?.lowercased() == "https" else {
          result(FlutterError(
            code: "INVALID_STORE_URL",
            message: "更新地址必须使用 HTTPS",
            details: nil
          ))
          return
        }
        DispatchQueue.main.async {
          UIApplication.shared.open(url, options: [:]) { opened in
            if opened {
              result(true)
            } else {
              result(FlutterError(
                code: "NO_HANDLER",
                message: "无法打开更新地址",
                details: nil
              ))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let recurringNotificationChannel = FlutterMethodChannel(
      name: "jizhang/recurring_notifications",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    recurringNotificationChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "APP_DELEGATE_UNAVAILABLE", message: nil, details: nil))
        return
      }
      switch call.method {
      case "requestPermission":
        UNUserNotificationCenter.current().requestAuthorization(
          options: [.alert, .sound, .badge]
        ) { granted, error in
          if let error {
            result(FlutterError(code: "NOTIFICATION_PERMISSION", message: error.localizedDescription, details: nil))
          } else {
            result(granted)
          }
        }
      case "schedule":
        self.scheduleRecurringNotification(call.arguments, result: result)
      case "cancel":
        guard let arguments = call.arguments as? [String: Any],
              let id = arguments["id"] as? String,
              !id.isEmpty else {
          result(FlutterError(code: "INVALID_REMINDER", message: "周期账单提醒 ID 为空", details: nil))
          return
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

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

  private func scheduleRecurringNotification(
    _ rawArguments: Any?,
    result: @escaping FlutterResult
  ) {
    guard let arguments = rawArguments as? [String: Any],
          let id = arguments["id"] as? String,
          let title = arguments["title"] as? String,
          let body = arguments["body"] as? String,
          let timestamp = arguments["timestamp"] as? NSNumber,
          let route = arguments["route"] as? String,
          !id.isEmpty,
          !route.isEmpty else {
      result(FlutterError(code: "INVALID_REMINDER", message: "周期账单提醒参数不完整", details: nil))
      return
    }
    let date = Date(timeIntervalSince1970: timestamp.doubleValue / 1000.0)
    let dateComponents = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: date
    )
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.userInfo = ["route": route]
    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [id])
    center.add(request) { error in
      if let error {
        result(FlutterError(code: "NOTIFICATION_SCHEDULE", message: error.localizedDescription, details: nil))
      } else {
        result(nil)
      }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let route = response.notification.request.content.userInfo["route"] as? String {
      emitNotificationRoute(route)
    }
    completionHandler()
  }

  private func emitNotificationRoute(_ route: String) {
    guard navigationChannel != nil else {
      pendingNotificationRoute = route
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
      self?.navigationChannel?.invokeMethod("openRoute", arguments: route)
    }
  }
}
