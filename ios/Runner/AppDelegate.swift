import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let naviChannel = FlutterMethodChannel(name: "com.example.wavi_app/kakao_navi", binaryMessenger: controller.binaryMessenger)

    naviChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "isKakaoNaviInstalled":
        result(self.isKakaoNaviInstalled())
        
             case "startKakaoNavi":
         guard let args = call.arguments as? [String: Any],
               let startLatitude = args["startLatitude"] as? Double,
               let startLongitude = args["startLongitude"] as? Double,
               let destinationName = args["destinationName"] as? String,
               let destinationLatitude = args["destinationLatitude"] as? Double,
               let destinationLongitude = args["destinationLongitude"] as? Double else {
           result(FlutterError(code: "INVALID_ARGUMENTS", message: "인수 오류", details: nil))
           return
         }
         self.startKakaoNavi(startLatitude: startLatitude, startLongitude: startLongitude, destinationName: destinationName, destinationLatitude: destinationLatitude, destinationLongitude: destinationLongitude)
         result(true)
        
      case "openKakaoNaviInstallPage":
        self.openKakaoNaviInstallPage()
        result(true)
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func isKakaoNaviInstalled() -> Bool {
    let kakaoNaviURL = URL(string: "kakaonavi://")!
    return UIApplication.shared.canOpenURL(kakaoNaviURL)
  }
  
  private func startKakaoNavi(startLatitude: Double, startLongitude: Double, destinationName: String, destinationLatitude: Double, destinationLongitude: Double) {
    // 출발지와 목적지가 모두 유효한지 확인
    if startLatitude == 0.0 && startLongitude == 0.0 {
      print("출발지 좌표가 유효하지 않습니다.")
      return
    }
    if destinationLatitude == 0.0 && destinationLongitude == 0.0 {
      print("목적지 좌표가 유효하지 않습니다.")
      return
    }
    
    // URL 인코딩된 장소명
    let encodedName = destinationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destinationName
    
    // 여러 카카오 앱 URL 스킴 시도 (정확한 형식 사용)
    let kakaoUrls = [
      // 카카오맵 - 가장 안정적인 형식
      "kakaomap://route?sp=\(startLatitude),\(startLongitude)&ep=\(destinationLatitude),\(destinationLongitude)&by=CAR",
      // 카카오 내비게이션 - 정확한 파라미터 형식
      "kakaonavi://navigate?name=\(encodedName)&x=\(destinationLongitude)&y=\(destinationLatitude)",
      // 카카오톡을 통한 링크
      "kakao://open?url=https://map.kakao.com/link/to/\(encodedName),\(destinationLatitude),\(destinationLongitude)"
    ]
    
    for urlString in kakaoUrls {
      if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
        return
      }
    }
    
    // 모든 카카오 앱이 실패한 경우 웹으로 열기
    let webURL = URL(string: "https://map.kakao.com/link/to/\(encodedName),\(destinationLatitude),\(destinationLongitude)")!
    UIApplication.shared.open(webURL)
  }
  
  private func openKakaoNaviInstallPage() {
    let appStoreURL = URL(string: "https://apps.apple.com/app/id675591583")!
    UIApplication.shared.open(appStoreURL)
  }
}