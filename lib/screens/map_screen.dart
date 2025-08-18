import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:geolocator/geolocator.dart';
import '../models/schedule.dart';
import '../widgets/location_picker.dart';

// 카카오 내비게이션 SDK 연동을 위한 패키지
import 'package:flutter/services.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  KakaoMapController? _mapController;
  LatLng _cameraCenter =  LatLng(37.5665, 126.9780);
  Marker? _currentLocationMarker;
  Marker? _selectedPlaceMarker;
  Location? _selectedLocation;
  bool _isLoadingLocation = true;

  // 선택된 마커의 정보를 저장할 변수
  String? _tappedMarkerId;
  Location? _tappedLocation;

  // Flutter 네이티브 채널
  static const platform = MethodChannel('com.example.wavi_app/kakao_navi');

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final Position position = await Geolocator.getCurrentPosition();
      final LatLng me = LatLng(position.latitude, position.longitude);
      print("현재 위치 : ${me}");

      setState(() {
        _cameraCenter = me;
        _currentLocationMarker = Marker(
          markerId: 'me',
          latLng: me,
        );
        _isLoadingLocation = false;

        // 지도가 생성되기 전에 마커 위치를 설정할 경우를 대비하여 컨트롤러를 통해 위치 설정
        _mapController?.setCenter(_cameraCenter);
      });

      if (_mapController != null) {
        await _mapController!.setCenter(me);
        await _mapController!.setLevel(4);
      }
    } catch (_) {
      setState(() => _isLoadingLocation = false);
    }
  }

  List<Marker> get _markers {
    return [
      if (_currentLocationMarker != null) _currentLocationMarker!,
      if (_selectedPlaceMarker != null) _selectedPlaceMarker!,
    ];
  }

  Future<void> _openLocationSearch() async {
    await showDialog(
      context: context,
      builder: (context) => LocationPicker(
        initialLocation: _selectedLocation,
        onLocationSelected: (Location? location) async {
          if (location == null) return;
          setState(() {
            _selectedLocation = location;
          });

          if (location.latitude != null && location.longitude != null) {
            final LatLng target = LatLng(location.latitude!, location.longitude!);
            setState(() {
              _selectedPlaceMarker = Marker(
                markerId: 'selected',
                latLng: target,
              );
              _cameraCenter = target;
            });
            if (_mapController != null) {
              await _mapController!.setCenter(target);
              await _mapController!.setLevel(3);
            }
          }
        },
      ),
    );
  }

  // 마커 탭 이벤트 핸들러
  Future<void> _onMarkerTap(String markerId, LatLng latLng) async {
    // 탭된 마커가 현재 위치 마커나 선택된 장소 마커인지 확인
    if (markerId == 'me') {
      setState(() {
        _tappedMarkerId = markerId;
        _tappedLocation = Location(
          name: '내 위치',
          latitude: latLng.latitude,
          longitude: latLng.longitude,
        );
      });
    } else if (markerId == 'selected') {
      setState(() {
        _tappedMarkerId = markerId;
        _tappedLocation = _selectedLocation;
      });
    }

    // 장소 정보 다이얼로그 띄우기
    _showPlaceInfoDialog();
  }

  void _showPlaceInfoDialog() {
    if (_tappedLocation == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _tappedMarkerId == 'me' ? Icons.my_location : Icons.location_on,
              color: _tappedMarkerId == 'me' ? Colors.blue : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(_tappedLocation!.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_tappedLocation!.address != null) ...[
              const Text('주소:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_tappedLocation!.address!),
              const SizedBox(height: 8),
            ],
            if (_tappedLocation!.latitude != null && _tappedLocation!.longitude != null) ...[
              const Text('좌표:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('위도: ${_tappedLocation!.latitude!.toStringAsFixed(6)}'),
              Text('경도: ${_tappedLocation!.longitude!.toStringAsFixed(6)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          if (_tappedLocation!.latitude != null && _tappedLocation!.longitude != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _startKakaoNavi(_tappedLocation!);
              },
              icon: const Icon(Icons.directions),
              label: const Text('길찾기'),
            ),
        ],
      ),
    );
  }

  // 카카오 내비게이션 길찾기
  Future<void> _startKakaoNavi(Location destination) async {
    try {
      // 현재 위치 가져오기
      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition();
        print('현재 위치: ${currentPosition.latitude}, ${currentPosition.longitude}');
      } catch (e) {
        print('현재 위치 가져오기 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('현재 위치를 가져올 수 없습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 카카오 내비게이션 앱이 설치되어 있는지 확인
      final bool isInstalled = await _checkKakaoNaviInstalled();
      print('카카오 내비게이션 설치 상태: $isInstalled');
      
      print('길찾기 시작:');
      print('출발지: ${currentPosition.latitude}, ${currentPosition.longitude}');
      print('목적지: ${destination.name} (${destination.latitude}, ${destination.longitude})');
      
      final dynamic result = await platform.invokeMethod('startKakaoNavi', {
        'startLatitude': currentPosition.latitude,
        'startLongitude': currentPosition.longitude,
        'destinationName': destination.name,
        'destinationLatitude': destination.latitude,
        'destinationLongitude': destination.longitude,
      });
      
      print('네비게이션 시작 결과: $result');
      
      // 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${destination.name}로 길찾기를 시작합니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } on PlatformException catch (e) {
      print("네비게이션 실행 실패: ${e.message}");
      // 사용자에게 에러 메시지 보여주기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('네비게이션 실행에 실패했습니다: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print("예상치 못한 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('길찾기 실행 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 카카오 내비게이션 앱 설치 여부 확인
  Future<bool> _checkKakaoNaviInstalled() async {
    try {
      final bool result = await platform.invokeMethod('isKakaoNaviInstalled');
      print('카카오 내비게이션 설치 확인 결과: $result');
      return result;
    } catch (e) {
      print('카카오 내비게이션 설치 확인 실패: $e');
      return false;
    }
  }

  // 카카오 내비게이션 설치 안내 다이얼로그
  void _showKakaoNaviInstallDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카카오 내비게이션 설치 필요'),
        content: const Text(
          '길찾기 기능을 사용하려면 카카오 내비게이션 앱이 필요합니다.\n'
          '앱스토어에서 카카오 내비게이션을 설치하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openKakaoNaviInstallPage();
            },
            child: const Text('설치하기'),
          ),
        ],
      ),
    );
  }

  // 카카오 내비게이션 설치 페이지 열기
  Future<void> _openKakaoNaviInstallPage() async {
    try {
      await platform.invokeMethod('openKakaoNaviInstallPage');
    } catch (e) {
      print('설치 페이지 열기 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설치 페이지를 열 수 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _openLocationSearch,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedLocation?.name ?? '장소를 검색하세요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF041E42).withOpacity(0.95),
                const Color(0xFF041E42).withOpacity(0.85),
                const Color(0xFF0A3D62).withOpacity(0.9),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF041E42).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
          Positioned.fill(
              child: KakaoMap(
                center: _cameraCenter,
                currentLevel: 4,
                markers: _markers,
                onMapCreated: (controller) async {
                  _mapController = controller;
                  await controller.setCenter(_cameraCenter);
                },
                onMarkerTap: (String markerId, LatLng latLng, int zoomLevel) {
                  _onMarkerTap(markerId, latLng);
                },
              ),
            ),
          if (_isLoadingLocation)
            const Positioned(
              top: 12,
              right: 12,
              child: Chip(label: Text('현재 위치 가져오는 중...')),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _initLocation();
        },
        icon: const Icon(Icons.my_location),
        label: const Text('현재 위치'),
      ),
    );
  }
}