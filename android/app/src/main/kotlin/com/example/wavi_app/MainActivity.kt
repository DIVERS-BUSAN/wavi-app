package com.example.wavi_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.wavi_app/kakao_navi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isKakaoNaviInstalled" -> {
                    result.success(isKakaoNaviInstalled())
                }
                "startKakaoNavi" -> {
                    val startLatitude = call.argument<Double>("startLatitude") ?: 0.0
                    val startLongitude = call.argument<Double>("startLongitude") ?: 0.0
                    val destinationName = call.argument<String>("destinationName") ?: ""
                    val destinationLatitude = call.argument<Double>("destinationLatitude") ?: 0.0
                    val destinationLongitude = call.argument<Double>("destinationLongitude") ?: 0.0
                    
                    startKakaoNavi(startLatitude, startLongitude, destinationName, destinationLatitude, destinationLongitude)
                    result.success(true)
                }
                "openKakaoNaviInstallPage" -> {
                    openKakaoNaviInstallPage()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isKakaoNaviInstalled(): Boolean {
        return try {
            // 카카오 내비게이션의 정확한 패키지명들 확인
            val kakaoNaviPackages = listOf(
                "com.locnall.KimGiSa",  // 카카오 내비게이션
                "net.daum.android.map",  // 카카오맵
                "com.kakao.talk"         // 카카오톡 (대안)
            )
            
            for (packageName in kakaoNaviPackages) {
                try {
                    packageManager.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
                    return true
                } catch (e: PackageManager.NameNotFoundException) {
                    continue
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun startKakaoNavi(startLatitude: Double, startLongitude: Double, destinationName: String, destinationLatitude: Double, destinationLongitude: Double) {
        try {
            // 출발지와 목적지가 모두 유효한지 확인
            if (startLatitude == 0.0 && startLongitude == 0.0) {
                throw Exception("출발지 좌표가 유효하지 않습니다.")
            }
            if (destinationLatitude == 0.0 && destinationLongitude == 0.0) {
                throw Exception("목적지 좌표가 유효하지 않습니다.")
            }

            // URL 인코딩된 장소명
            val encodedName = java.net.URLEncoder.encode(destinationName, "UTF-8")
            
            // 여러 카카오 앱 URL 스킴 시도 (정확한 형식 사용)
            val kakaoUrls = listOf(
                // 카카오맵 - 가장 안정적인 형식
                "kakaomap://route?sp=$startLatitude,$startLongitude&ep=$destinationLatitude,$destinationLongitude&by=CAR",
                // 카카오 내비게이션 - 정확한 파라미터 형식
                "kakaonavi://navigate?name=$encodedName&x=$destinationLongitude&y=$destinationLatitude",
                // 카카오톡을 통한 링크
                "kakao://open?url=https://map.kakao.com/link/to/$encodedName,$destinationLatitude,$destinationLongitude"
            )
            
            var success = false
            for (urlString in kakaoUrls) {
                try {
                    val intent = Intent(Intent.ACTION_VIEW)
                    val uri = Uri.parse(urlString)
                    intent.data = uri
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    success = true
                    break
                } catch (e: Exception) {
                    continue
                }
            }
            
            // 모든 카카오 앱이 실패한 경우 웹으로 열기
            if (!success) {
                val webIntent = Intent(Intent.ACTION_VIEW)
                val webUri = Uri.parse("https://map.kakao.com/link/to/$encodedName,$destinationLatitude,$destinationLongitude")
                webIntent.data = webUri
                startActivity(webIntent)
            }
        } catch (e: Exception) {
            // 최종 실패 시 웹으로 열기
            val webIntent = Intent(Intent.ACTION_VIEW)
            val webUri = Uri.parse("https://map.kakao.com/link/to/$destinationName,$destinationLatitude,$destinationLongitude")
            webIntent.data = webUri
            startActivity(webIntent)
        }
    }

    private fun openKakaoNaviInstallPage() {
        try {
            val intent = Intent(Intent.ACTION_VIEW)
            intent.data = Uri.parse("market://details?id=com.locnall.KimGiSa")
            startActivity(intent)
        } catch (e: Exception) {
            // 구글 플레이가 없는 경우 웹으로 열기
            val webIntent = Intent(Intent.ACTION_VIEW)
            webIntent.data = Uri.parse("https://play.google.com/store/apps/details?id=com.locnall.KimGiSa")
            startActivity(webIntent)
        }
    }
}
