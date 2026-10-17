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
    registerBackupExclusion(engineBridge.pluginRegistry)
  }

  /// The downloaded archive can be fetched again, so it stays out of iCloud
  /// backups. Setting the flag on the folder covers everything inside it.
  private func registerBackupExclusion(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "AtdtBackupExclusion") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "org.prouse.atdt/backup",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup",
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      var url = URL(fileURLWithPath: path, isDirectory: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try url.setResourceValues(values)
        result(true)
      } catch {
        result(
          FlutterError(code: "backup", message: error.localizedDescription, details: path))
      }
    }
  }
}
