import AppIntents
import BackgroundTasks
import Flutter
import UIKit
import UserNotifications
import Vision

@available(iOS 16.0, *)
struct HaoHaoBookkeepingShortcutIntent: AppIntent {
  static var title: LocalizedStringResource = "记一笔到好好记账"
  static var description = IntentDescription("把一段账单文字发送到好好记账，打开后确认再保存。")
  static var openAppWhenRun: Bool = true

  @Parameter(title: "账单文字", requestValueDialog: IntentDialog("例如：午餐 28 元微信支付"))
  var text: String

  func perform() async throws -> some IntentResult {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
      throw NSError(
        domain: "HaoHaoBookkeepingShortcut",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "账单文字不能为空"]
      )
    }
    let defaults = UserDefaults.standard
    defaults.set(value, forKey: "haohao.shortcut.pendingText")
    defaults.set(false, forKey: "haohao.shortcut.routeSent")
    return .result()
  }
}

@available(iOS 16.0, *)
struct HaoHaoBookkeepingShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    [
      AppShortcut(
        intent: HaoHaoBookkeepingShortcutIntent(),
        phrases: [
          "用\(.applicationName)记账",
          "在\(.applicationName)记一笔"
        ],
        shortTitle: "记一笔",
        systemImageName: "plus.circle"
      )
    ]
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var navigationChannel: FlutterMethodChannel?
  private var pendingNotificationRoute: String?
  private var apnsDeviceToken: String?
  private let financeTaskIdentifier = "com.algive.jizhang.finance.refresh"
  private var backgroundFinanceEngine: FlutterEngine?
  private var backgroundFinanceChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    apnsDeviceToken = UserDefaults.standard.string(forKey: "haohao.apns.deviceToken")
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: financeTaskIdentifier,
      using: nil
    ) { [weak self] task in
      guard let refreshTask = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      self?.handleFinanceRefresh(refreshTask)
    }
    scheduleFinanceRefresh()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    navigationChannel = FlutterMethodChannel(
      name: "jizhang/navigation",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    let pushChannel = FlutterMethodChannel(
      name: "jizhang/push",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    pushChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "currentToken" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if let token = self?.apnsDeviceToken, !token.isEmpty {
        result([
          "platform": "ios",
          "provider": "apns",
          "token": token,
        ])
        return
      }
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
      // APNs registration is asynchronous. A later foreground registration
      // attempt will return the token after didRegisterForRemoteNotifications.
      result(nil)
    }
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

    let shortcutChannel = FlutterMethodChannel(
      name: "jizhang/ios_shortcut",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    shortcutChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "takePendingText":
        let defaults = UserDefaults.standard
        let text = defaults.string(forKey: "haohao.shortcut.pendingText")
        defaults.removeObject(forKey: "haohao.shortcut.pendingText")
        defaults.set(false, forKey: "haohao.shortcut.routeSent")
        result(text)
      case "isAvailable":
        if #available(iOS 16.0, *) {
          result(true)
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let financeSchedulerChannel = FlutterMethodChannel(
      name: "jizhang/finance_scheduler",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    financeSchedulerChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "APP_DELEGATE_UNAVAILABLE", message: nil, details: nil))
        return
      }
      switch call.method {
      case "schedule":
        self.scheduleFinanceRefresh()
        result(nil)
      case "cancel":
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: self.financeTaskIdentifier)
        result(nil)
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

    let ocrChannel = FlutterMethodChannel(
      name: "jizhang/local_ocr",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    ocrChannel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let path = arguments["path"] as? String,
            !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let image = UIImage(contentsOfFile: path),
            let cgImage = image.cgImage else {
        result(FlutterError(
          code: "INVALID_IMAGE",
          message: "OCR image cannot be loaded",
          details: nil
        ))
        return
      }

      DispatchQueue.global(qos: .userInitiated).async {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
          try handler.perform([request])
          let lines = (request.results ?? []).compactMap {
            $0.topCandidates(1).first?.string
          }
          DispatchQueue.main.async {
            result([
              "text": lines.joined(separator: "\n"),
              "blocks": lines,
            ])
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "OCR_FAILED",
              message: error.localizedDescription,
              details: nil
            ))
          }
        }
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

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    let defaults = UserDefaults.standard
    let pending = defaults.string(forKey: "haohao.shortcut.pendingText")
    let routeSent = defaults.bool(forKey: "haohao.shortcut.routeSent")
    if let pending, !pending.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !routeSent {
      defaults.set(true, forKey: "haohao.shortcut.routeSent")
      emitNotificationRoute("/profile/autobookkeeping/shortcut")
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    apnsDeviceToken = token
    UserDefaults.standard.set(token, forKey: "haohao.apns.deviceToken")
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
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

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let route = response.notification.request.content.userInfo["route"] as? String {
      emitNotificationRoute(route)
    }
    completionHandler()
  }

  private func scheduleFinanceRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: financeTaskIdentifier)
    // iOS decides the exact execution time. Six hours keeps the daily finance
    // task eligible without pretending BGTaskScheduler is an exact alarm.
    request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      // Foreground resume processing remains the fallback when iOS declines a
      // background request (for example, Background App Refresh is disabled).
    }
  }

  private func handleFinanceRefresh(_ task: BGAppRefreshTask) {
    // BGAppRefresh requests are one-shot. Schedule the next opportunity before
    // running this one so a process termination cannot silently stop the chain.
    scheduleFinanceRefresh()

    let engine = FlutterEngine(
      name: "haohao-finance-background",
      project: nil,
      allowHeadlessExecution: true
    )
    backgroundFinanceEngine = engine
    guard engine.run(withEntrypoint: "scheduledFinanceMain") else {
      backgroundFinanceEngine = nil
      task.setTaskCompleted(success: false)
      return
    }
    GeneratedPluginRegistrant.register(with: engine)

    let channel = FlutterMethodChannel(
      name: "jizhang/finance_scheduler",
      binaryMessenger: engine.binaryMessenger
    )
    backgroundFinanceChannel = channel
    var didFinish = false

    func finish(_ success: Bool) {
      guard !didFinish else { return }
      didFinish = true
      channel.setMethodCallHandler(nil)
      backgroundFinanceChannel = nil
      backgroundFinanceEngine?.destroyContext()
      backgroundFinanceEngine = nil
      task.setTaskCompleted(success: success)
    }

    task.expirationHandler = {
      DispatchQueue.main.async {
        finish(false)
      }
    }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "APP_DELEGATE_UNAVAILABLE", message: nil, details: nil))
        finish(false)
        return
      }
      switch call.method {
      case "scheduleReminder":
        self.scheduleRecurringNotification(call.arguments, result: result)
      case "cancelReminder":
        guard let arguments = call.arguments as? [String: Any],
              let id = arguments["id"] as? String,
              !id.isEmpty else {
          result(FlutterError(code: "INVALID_REMINDER", message: "周期账单提醒 ID 为空", details: nil))
          return
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
          withIdentifiers: [id]
        )
        result(nil)
      case "completed":
        result(nil)
        finish(true)
      case "failed":
        result(nil)
        finish(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
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
