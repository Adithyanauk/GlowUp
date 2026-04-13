import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let mediapipeChannel = "glowup/mediapipe"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: mediapipeChannel,
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { call, result in
        if call.method == "processFrame" {
          // TODO: Hook MediaPipe Tasks (Face Landmarker + Pose Landmarker)
          // and return normalized landmark coordinates.
          result([
            "poseLandmarks": [],
            "faceLandmarks": [],
          ])
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
