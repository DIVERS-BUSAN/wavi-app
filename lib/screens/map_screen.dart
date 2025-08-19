import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:geolocator/geolocator.dart';
import '../models/schedule.dart';
import '../widgets/location_picker.dart';
import '../services/schedule_service.dart';
import 'package:intl/intl.dart';

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
  
  // 일정 관련 변수
  final ScheduleService _scheduleService = ScheduleService();
  List<Schedule> _schedules = [];
  List<Marker> _scheduleMarkers = [];
  List<Polyline> _routePolylines = [];
  DateTime _selectedDate = DateTime.now();
  bool _showDateSchedules = false;

  // 선택된 마커의 정보를 저장할 변수
  String? _tappedMarkerId;
  Location? _tappedLocation;
  Schedule? _tappedSchedule;

  // Flutter 네이티브 채널
  static const platform = MethodChannel('com.example.wavi_app/kakao_navi');

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadSchedules();
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

  Future<void> _loadSchedules() async {
    final schedules = await _scheduleService.getAllSchedules();
    
    // 장소가 있는 일정만 필터링
    var schedulesWithLocation = schedules.where((schedule) => 
      schedule.location != null && 
      schedule.location!.latitude != null && 
      schedule.location!.longitude != null
    ).toList();
    
    // 날짜 필터 적용
    if (_showDateSchedules) {
      schedulesWithLocation = schedulesWithLocation.where((schedule) {
        return schedule.dateTime.year == _selectedDate.year &&
               schedule.dateTime.month == _selectedDate.month &&
               schedule.dateTime.day == _selectedDate.day;
      }).toList();
      
      // 시간순 정렬
      schedulesWithLocation.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }
    
    setState(() {
      _schedules = schedulesWithLocation;
      _scheduleMarkers = _createScheduleMarkers();
      _routePolylines = _createRoutePolylines();
    });
  }

  List<Marker> _createScheduleMarkers() {
    return _schedules.asMap().entries.map((entry) {
      final index = entry.key;
      final schedule = entry.value;
      
      return Marker(
        markerId: 'schedule_${schedule.id}',
        latLng: LatLng(
          schedule.location!.latitude!,
          schedule.location!.longitude!,
        ),
      );
    }).toList();
  }

  List<Polyline> _createRoutePolylines() {
    if (!_showDateSchedules || _schedules.length < 2) {
      return [];
    }
    
    List<Polyline> polylines = [];
    
    for (int i = 0; i < _schedules.length - 1; i++) {
      final current = _schedules[i];
      final next = _schedules[i + 1];
      
      if (current.location?.latitude != null && 
          current.location?.longitude != null &&
          next.location?.latitude != null && 
          next.location?.longitude != null) {
        
        polylines.add(
          Polyline(
            polylineId: 'route_$i',
            points: [
              LatLng(current.location!.latitude!, current.location!.longitude!),
              LatLng(next.location!.latitude!, next.location!.longitude!),
            ],
          ),
        );
      }
    }
    
    return polylines;
  }

  List<Marker> get _markers {
    return [
      if (_currentLocationMarker != null) _currentLocationMarker!,
      if (_selectedPlaceMarker != null) _selectedPlaceMarker!,
      ..._scheduleMarkers,
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
        _tappedSchedule = null;
      });
    } else if (markerId == 'selected') {
      setState(() {
        _tappedMarkerId = markerId;
        _tappedLocation = _selectedLocation;
        _tappedSchedule = null;
      });
    } else if (markerId.startsWith('schedule_')) {
      // 일정 마커가 탭된 경우
      final scheduleId = markerId.replaceFirst('schedule_', '');
      final schedule = _schedules.firstWhere((s) => s.id == scheduleId);
      setState(() {
        _tappedMarkerId = markerId;
        _tappedLocation = schedule.location;
        _tappedSchedule = schedule;
      });
    }

    // 장소 정보 다이얼로그 띄우기
    _showPlaceInfoDialog();
  }

  void _showPlaceInfoDialog() {
    if (_tappedLocation == null) return;

    // 아이콘 결정
    IconData iconData;
    Color iconColor;
    if (_tappedMarkerId == 'me') {
      iconData = Icons.my_location;
      iconColor = Colors.blue;
    } else if (_tappedSchedule != null) {
      iconData = Icons.event;
      iconColor = Color(_tappedSchedule!.color.colorValue);
    } else {
      iconData = Icons.location_on;
      iconColor = Colors.red;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(iconData, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_tappedLocation!.name, style: const TextStyle(fontSize: 16)),
                  if (_tappedSchedule != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MM월 dd일 HH:mm').format(_tappedSchedule!.dateTime),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_tappedSchedule != null && _tappedSchedule!.description != null) ...[
              const Text('일정 내용:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_tappedSchedule!.description!),
              const SizedBox(height: 8),
            ],
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

  // 일정 목록 보기
  void _showSchedulesList() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.route, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MM월 dd일 일정').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = _schedules[index];
                    return ListTile(
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(schedule.color.colorValue),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(schedule.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('HH:mm').format(schedule.dateTime)),
                          if (schedule.location != null)
                            Text(
                              schedule.location!.name,
                              style: TextStyle(color: Colors.red[600], fontSize: 12),
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (schedule.location?.latitude != null && 
                            schedule.location?.longitude != null) {
                          _mapController?.setCenter(LatLng(
                            schedule.location!.latitude!,
                            schedule.location!.longitude!,
                          ));
                          _mapController?.setLevel(3);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
                // polylines: Set<Polyline>.from(_routePolylines), // 카카오 지도 플러그인에서 폴리라인 지원 확인 필요
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
          // 현재 위치 버튼
          Positioned(
            top: 16,
            left: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: () async {
                await _initLocation();
              },
              backgroundColor: Colors.white,
              child: Icon(Icons.my_location, color: Colors.green[700]),
            ),
          ),
          // 날짜 선택 및 일정 표시 컨트롤
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                _selectedDate = pickedDate;
                                _showDateSchedules = true;
                              });
                              await _loadSchedules();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              DateFormat('yyyy년 MM월 dd일').format(_selectedDate),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _showDateSchedules,
                        onChanged: (value) async {
                          setState(() {
                            _showDateSchedules = value;
                          });
                          await _loadSchedules();
                        },
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  if (_showDateSchedules && _schedules.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.route, color: Colors.green[700], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${_schedules.length}개 일정',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              // 일정 목록 보기
                              _showSchedulesList();
                            },
                            icon: Icon(Icons.list, size: 16, color: Colors.green[700]),
                            label: Text(
                              '목록보기',
                              style: TextStyle(fontSize: 13, color: Colors.green[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}