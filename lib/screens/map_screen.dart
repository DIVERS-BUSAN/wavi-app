import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/schedule.dart';
import '../widgets/location_picker.dart';
import '../services/schedule_service.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:kakao_flutter_sdk_navi/kakao_flutter_sdk_navi.dart'as kakao_navi;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  KakaoMapController? _mapController;

  // 위치 변수
  LatLng _cameraCenter =  LatLng(37.5665, 126.9780);
  Location? _selectedLocation;
  Location? finalDestination;
  bool _isLoadingLocation = true;
  List<Location> allSchedules = [];

  // 마커 변수
  Marker? _currentLocationMarker;
  Marker? _selectedPlaceMarker;

  //경유지 변수
  List<kakao_navi.Location> viaList = [];

  // 일정 관련 변수
  final ScheduleService _scheduleService = ScheduleService();
  List<Schedule> _schedules = [];
  List<Marker> _scheduleMarkers = [];
  DateTime _selectedDate = DateTime.now();
  bool _showDateSchedules = false;

  // 선택된 마커의 정보를 저장할 변수
  String? _tappedMarkerId;
  Location? _tappedLocation;
  Schedule? _tappedSchedule;

  // 루트 경로 여부
  bool _routenavigation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocation();
    loadSchedules();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아올 때 일정 새로고침
      loadSchedules();
    }
  }
  
  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 위젯이 업데이트될 때마다 일정을 새로고침
    loadSchedules();
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

      await _getCurrentLocation();

  }catch (_) {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _getCurrentLocation() async{
    final Position position = await Geolocator.getCurrentPosition();
    final LatLng me = LatLng(position.latitude, position.longitude);
    print("현재 위치 : ${me}");

    setState(() async{
      _currentLocationMarker = Marker(
        markerId: 'me',
        latLng: me,
      );
      _isLoadingLocation = false;

      await _mapController!.setCenter(me);
      _mapController!.setLevel(4);
    });

    if (_mapController != null) {
      await _mapController!.setCenter(me);
      _mapController!.setLevel(4);
    }
  }

  Future<kakao_navi.Location> to_kakao(Location location) async {
    kakao_navi.Location result;

    result = kakao_navi.Location(
        name: location.name,
        y: location.latitude.toString(),
        x: location.longitude.toString()
    );

    return result;
  }

  Future<void> loadSchedules() async {
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
          name: AppLocalizations.of(context).myLocation,
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
    final l10n = AppLocalizations.of(context);

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
                      DateFormat(context.read<LanguageProvider>().isEnglish ? 'MMM dd HH:mm' : 'MM월 dd일 HH:mm').format(_tappedSchedule!.dateTime),
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
              Text(l10n.scheduleContent, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_tappedSchedule!.description!),
              const SizedBox(height: 8),
            ],
            if (_tappedLocation!.address != null) ...[
              Text(l10n.address, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_tappedLocation!.address!),
              const SizedBox(height: 8),
            ],
            if (_tappedLocation!.latitude != null && _tappedLocation!.longitude != null) ...[
              Text(l10n.coordinates, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${l10n.latitude}: ${_tappedLocation!.latitude!.toStringAsFixed(6)}'),
              Text('${l10n.longitude}: ${_tappedLocation!.longitude!.toStringAsFixed(6)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
          if (_tappedLocation!.latitude != null && _tappedLocation!.longitude != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showTravelModeDialog(_tappedLocation!);
              },
              icon: const Icon(Icons.directions),
              label: Text(l10n.navigate),
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
        final l10n = AppLocalizations.of(context);
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
                    l10n.dailySchedule(_selectedDate),
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
  Future<void> _startKakaoNavi(
      Location destination, {
        String travelMode = 'CAR',
      }) async {

    viaList.forEach((via){
      print("삭제전 경유지 ${via.name}");
    });

    kakao_navi.Location kDestination = await to_kakao(destination);

    // 경유지에 목적지가 중목되면 제거
    viaList.removeWhere((waypoint) =>
    waypoint.y == kDestination.y &&
        waypoint.x == kDestination.x);

    viaList.forEach((via){
      print("삭제후 경유지 ${via.name}");
    });

    print("목적지: ${kDestination.name}");


    bool isKakaoNaviInstalled = await kakao_navi.NaviApi.instance.isKakaoNaviInstalled();

    if (isKakaoNaviInstalled) {
      if (travelMode == 'CAR') {
        // 차량 길안내
        try {
          await kakao_navi.NaviApi.instance.shareDestination(
            destination: kakao_navi.Location(
              x: kDestination.x,
              y: kDestination.y,
              name: kDestination.name
            ),
            option: kakao_navi.NaviOption(
                coordType: kakao_navi.CoordType.wgs84),
            viaList: viaList,
          );
        } catch (e) {
          print('에러 발생 :  ${e}');
        }
      } else {
        // 도보 길안내 (카카오맵 URL 스킴 방식)
        try {
          final queryParameters = {
            'ep': '${destination.latitude},${destination.longitude}',
            'by': 'FOOT',
          };

          for (int i = 0; i < viaList.length; i++) {
            final waypoint = viaList[i];
            final name = Uri.encodeComponent(waypoint.name);
            final lat = waypoint.y;
            final lng = waypoint.x;
            queryParameters['via\${i + 1}'] = '\$name,\$lat,\$lng';
          };

          final uri = Uri(
            scheme: 'kakaomap',
            host: 'route',
            queryParameters: queryParameters,
          );

          print('생성된 도보 길안내 URL: $uri');

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            // 카카오맵이 없으면 웹으로 열기
            final webUrl = 'https://map.kakao.com/link/to/${destination
                .name},${destination.latitude},${destination.longitude}';
            await launchUrl(Uri.parse(webUrl));
          }
        } catch (e) {
          print('도보 길안내 실패: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('도보 길안내를 실행할 수 없습니다.')),
          );
        }
      }
    }
    else {
      try {
        String installUrl = kakao_navi.NaviApi.webNaviInstall;
        Uri uri = Uri.parse(installUrl);

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw 'Could not launch $uri';
        }
      } catch (e) {
        print('설치 페이지 열기 실패: $e');
      }
    }
  }
  // 여행 수단 선택 다이얼로그
  void _showTravelModeDialog(Location location) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chooseTravelMode),
        content: Text(l10n.howToTravel),
        actions: <Widget>[
          TextButton.icon(
            icon: const Icon(Icons.directions_walk, color: Colors.blue),
            label: Text(
              l10n.walking,
              style: const TextStyle(color: Colors.blue),
            ),
            onPressed: () {
              Navigator.pop(context);
              _startKakaoNavi(location!, travelMode: 'FOOT');
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.directions_car, color: Colors.green),
            label: Text(
              l10n.driving,
              style: const TextStyle(color: Colors.green),
            ),
            onPressed: () {
              //print("목적지 ${finalDestination!.name}");
              Navigator.pop(context);
              _startKakaoNavi(location!, travelMode: 'CAR');
            },
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
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
                    _selectedLocation?.name ?? l10n.searchLocation,
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
            Positioned(
              top: 12,
              right: 12,
              child: Chip(label: Text(l10n.currentLocationLoading)),
            ),
          // 현재 위치 버튼
          Positioned(
            top: 16,
            left: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: () async {
                await _getCurrentLocation();
              },
              backgroundColor: Colors.white,
              child: Icon(Icons.my_location, color: Colors.green[700]),
            ),
          ),
          // 날짜 선택 및 일정 표시 컨트롤
          Positioned(
            bottom: 40, // WAVI 버튼과 겹치지 않도록 높이 조정
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
              // 달력 클릭
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

                            if (pickedDate == null) return;

                            await loadSchedules();
                            allSchedules = [];
                            viaList = [];

                            if (_schedules.isNotEmpty) {
                              // 출발지 추가
                              print('출발지: ${_currentLocationMarker!.latLng}');
                              allSchedules.add(Location(
                                  name: 'start',
                                  latitude: _currentLocationMarker!.latLng.latitude,
                                  longitude: _currentLocationMarker!.latLng.longitude
                              ));

                              // 경유지 및 도착지 처리
                              for (int i = 0; i < _schedules.length; i++) {
                                var waypoint = _schedules[i].location!;
                                var kakao = await to_kakao(waypoint);

                                if (i == _schedules.length - 1) {
                                  // 마지막 항목은 도착지로 설정
                                  print('목적지: ${waypoint.name}');
                                  finalDestination = waypoint;
                                  allSchedules.add(finalDestination!);
                                  continue;
                                }
                                print('경유지: ${waypoint.name}');
                                viaList.add(kakao);
                                allSchedules.add(waypoint);
                              }
                            }

                            setState(() {
                              _selectedDate = pickedDate;
                              _showDateSchedules = true;
                              _routenavigation = true;
                            });

                            if (_mapController != null && allSchedules.isNotEmpty) {
                              List<LatLng> bounds = allSchedules.map((location) {
                                return LatLng(location.latitude!, location.longitude!);
                              }).toList();

                              if (bounds.isNotEmpty) {
                                _mapController!.fitBounds(bounds);
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              DateFormat(context.read<LanguageProvider>().isEnglish ? 'MMM dd yyyy' : 'yyyy년 MM월 dd일').format(_selectedDate),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 일정 스위치
                      Switch(
                        value: _showDateSchedules,
                        onChanged: (value) async {
                          setState(()  {
                            _showDateSchedules = value;
                          });
                          if (value) {
                            await loadSchedules();
                            _showDateSchedules = true;

                              setState(() {
                                //화면 조정
                                if (_mapController != null) {
                                  List<LatLng> bounds = allSchedules.map((location) {
                                    return LatLng(location.latitude!, location.longitude!);
                                  }).toList();

                                  if (bounds.isNotEmpty) {
                                  _mapController!.fitBounds(bounds);
                                  }
                                }
                              });
                              if(finalDestination != null)
                                _routenavigation = true;
                          } else {
                            //viaList = [];
                            //finalDestination = null;
                            //allSchedules.clear();
                            _routenavigation = false;
                          }
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
                          Flexible(
                            child: Text(
                              l10n.scheduleCount(_schedules.length),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: TextButton.icon(
                              onPressed: () {
                                // 일정 목록 보기
                                _showSchedulesList();
                              },
                              icon: Icon(Icons.list, size: 16, color: Colors.green[700]),
                              label: Text(
                                l10n.listView,
                                style: TextStyle(fontSize: 13, color: Colors.green[700]),
                              ),
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
            // 길안내
            if(_routenavigation)
              Positioned(
                  bottom: 190,
                  left: 55,
                  right: 90,
                  child: FloatingActionButton(
                    child: Text('길찾기'),
                      onPressed: (){
                      _showTravelModeDialog(finalDestination!);
                      }
                  )
              )
          ],
        ),
      ),
    );
  }
}