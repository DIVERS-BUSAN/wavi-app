import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/placedetail.dart';
import '../models/schedule.dart';
import '../widgets/location_picker.dart';
import '../widgets/place_detail_viewer.dart';
import '../services/schedule_service.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/toast_utils.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart' show NetworkAssetBundle;
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
  List<Polyline> _polylines = []; //폴리라인추가
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
  ScheduleService _scheduleService = ScheduleService();
  List<Schedule> _schedules = [];
  List<Marker> _scheduleMarkers = [];
  DateTime _selectedDate = DateTime.now();
  bool _showDateSchedules = false;

  // 선택된 마커의 정보를 저장할 변수
  String? _tappedMarkerId;
  Location? _tappedLocation;
  Schedule? _tappedSchedule;

  //polyline 변수
  Polyline? _routePolyline;

  // 루트 경로 여부
  bool _routenavigation = false;

  // 스프라이트 원본 URL (카카오 공식 문서 이미지)
  static const _spriteUrl = 'https://t1.daumcdn.net/localimg/localimages/07/mapapidoc/marker_number_blue.png';
  // 캐시용
  ui.Image? _spriteImage;

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
        if (!mounted) return; // ✅ mounted 체크
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
    Position position = await Geolocator.getCurrentPosition();
    LatLng me = LatLng(position.latitude, position.longitude);
    print("현재 위치 : ${me}");

    if (_mapController != null) {
      await _mapController!.setCenter(me);
      _mapController!.setLevel(4);
    }

    //final startIcon = await MarkerIcon.fromNetwork(
    //  'https://maps.gstatic.com/mapfiles/ms2/micons/green-dot.png',
    //);

    if (!mounted) return; // ✅ 위젯이 살아있을 때만 실행

    setState(() {
      _currentLocationMarker = Marker(
        markerId: 'me',
        latLng: me,
      );
      _isLoadingLocation = false;
    });

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

  Future<void> loadSchedules({bool forceShowDateSchedules = false}) async {
    final schedules = await _scheduleService.getAllSchedules();
    
    // 장소가 있는 일정만 필터링
    var schedulesWithLocation = schedules.where((schedule) => 
      schedule.location != null && 
      schedule.location!.latitude != null && 
      schedule.location!.longitude != null
    ).toList();
    
    // 날짜 필터 적용
    if (_showDateSchedules || forceShowDateSchedules) {
      schedulesWithLocation = schedulesWithLocation.where((schedule) {
        return schedule.dateTime.year == _selectedDate.year &&
               schedule.dateTime.month == _selectedDate.month &&
               schedule.dateTime.day == _selectedDate.day;
      }).toList();
      
      // 시간순 정렬
      schedulesWithLocation.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }

    var markers = await _createScheduleMarkers(schedulesWithLocation);

    setState(() {
      _schedules = schedulesWithLocation;
      _scheduleMarkers = markers;
    });
  }

  Future<List<Marker>> _createScheduleMarkers(List<Schedule> list) async {
    List<Marker> markers = [];

    for (int i = 0; i < list.length; i++) {
      var schedule = list[i];
      var lat = schedule.location!.latitude!;
      var lng = schedule.location!.longitude!;

      if(i%2 != 0){
        if (i == list.length - 1) {
          //도착지
          markers.add(
            Marker(
                markerId: 'schedule_${schedule.id}',
                latLng: LatLng(lat, lng),
                markerImageSrc: 'http://t1.daumcdn.net/localimg/localimages/07/mapapidoc/markerStar.png',
                width: 24,
                height: 32
            ),
          );
        } else {
          final dataUrl = await _numberMarkerDataUrl(i-1);
          //경유지
          markers.add(
            Marker(
                markerId: 'schedule_${schedule.id}',
                latLng: LatLng(lat, lng),
                markerImageSrc: dataUrl,
                width: 35,
                height: 35
            ),
          );
        }
      }
    }
    return markers;
  }

  /// 특정 index의 숫자 마커 아이콘 잘라오기
  Future<void> _ensureSpriteLoaded() async {
    if (_spriteImage != null) return;
    final byteData = await NetworkAssetBundle(Uri.parse(_spriteUrl)).load('');
    final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _spriteImage = frame.image;
  }

  // 1,2,3... 에 해당하는 숫자 마커를 스프라이트에서 잘라 data URL로 반환
  Future<String> _numberMarkerDataUrl(int idx) async {
    // kakao JS 문서 기준 값
    const int w = 36;        // 아이콘 폭
    const int h = 37;        // 아이콘 높이
    const int stride = 46;   // 각 아이템 간 세로 이동량
    const int topPad = 10;   // 맨 위 여백
    final int srcY = (idx * stride) + topPad;

    await _ensureSpriteLoaded();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint();

    canvas.drawImageRect(
      _spriteImage!,
      ui.Rect.fromLTWH(0, srcY.toDouble(), w.toDouble(), h.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      paint,
    );

    final cropped = await recorder.endRecording().toImage(w, h);
    final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
    final b64 = base64Encode(png!.buffer.asUint8List());
    return 'data:image/png;base64,$b64';
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

  /// 좌표를 주소로 변환하는 함수 (카카오 REST API 사용)
  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    final url = Uri.parse('https://dapi.kakao.com/v2/local/geo/coord2address.json?x=$lon&y=$lat');
    final String API_KEY = dotenv.env['KAKAO_REST_API_KEY']! ?? '';

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'KakaoAK $API_KEY'}
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['documents'] != null && data['documents'].isNotEmpty) {
          final documents = data['documents'][0];
          // 도로명 주소가 있으면 그것을, 없으면 지번 주소를 반환
          final roadAddress = documents['road_address'];
          if (roadAddress != null && roadAddress['address_name'] != null) {
            return roadAddress['address_name'];
          }
          final address = documents['address'];
          if (address != null && address['address_name'] != null) {
            return address['address_name'];
          }
        }
      }
      return '주소를 찾을 수 없습니다.';
    } catch (e) {
      print('주소 변환 API 오류: $e');
      return '주소를 불러오는 데 실패했습니다.';
    }
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
      var scheduleId = markerId.replaceFirst('schedule_', '');
      var schedule = _schedules.firstWhere((s) => s.id == scheduleId);
      setState(() {
        _tappedMarkerId = markerId;
        _tappedLocation = schedule.location;
        _tappedSchedule = schedule;
      });
    }

    // 장소 정보 다이얼로그 띄우기
    //_showPlaceInfoDialog();
    _showLocationDetailsSheet(location: _tappedLocation!, markerId: _tappedMarkerId!,);
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

  void _showLocationDetailsSheet({
    required Location location,
    required String markerId,
    Schedule? schedule,
  }) {
    final l10n = AppLocalizations.of(context);

    IconData iconData;
    Color iconColor;
    if (markerId == 'me') {
      iconData = Icons.my_location;
      iconColor = Colors.blue;
    } else if (schedule != null) {
      iconData = Icons.event;
      iconColor = Color(schedule.color.colorValue);
    } else {
      iconData = Icons.location_on;
      iconColor = Colors.red;
    }

    showModalBottomSheet(

      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Wrap( // Wrap을 사용하여 내용에 따라 높이가 유연하게 조절되도록 함
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 제목 섹션 ---
                  Row(
                    children: [
                      Icon(iconData, color: iconColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(location.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            if (schedule != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(context.read<LanguageProvider>().isEnglish ? 'MMM dd, HH:mm' : 'MM월 dd일 HH:mm').format(schedule.dateTime),
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                    ],
                  ),
                  const Divider(height: 24),

                  FutureBuilder<PlaceDetails?>(
                    future: getPlaceDetails(location),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                        // API 호출 실패 또는 데이터 없을 시 기본 정보만 표시
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(icon: Icons.map_outlined, text: location.address ?? '주소 정보 없음'),
                            const SizedBox(height: 16),
                            Text(l10n.coordinates, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${l10n.latitude}: ${location.latitude!.toStringAsFixed(6)}'),
                            Text('${l10n.longitude}: ${location.longitude!.toStringAsFixed(6)}'),
                          ],
                        );
                      }

                      final details = snapshot.data!;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(icon: Icons.category_outlined, text: details.category),
                          _buildDetailRow(icon: Icons.map_outlined, text: details.address),
                          if (details.phone.isNotEmpty && details.phone != '정보 없음')
                            _buildDetailRow(icon: Icons.phone_outlined, text: details.phone),

                          const SizedBox(height: 20),

                          // --- 버튼 섹션 ---
                          Row(
                            children: [
                              if (details.placeUrl.isNotEmpty)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      showDialog(
                                        context: context,
                                        builder: (context) => PlaceDetailViewer(
                                          placeUrl: details.placeUrl,
                                          placeName: location.name,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.info_outline),
                                    label: const Text('카카오맵 정보'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              if (details.placeUrl.isNotEmpty)
                                const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showTravelModeDialog(location);
                                  },
                                  icon: const Icon(Icons.directions),
                                  label: Text(l10n.navigate),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 상세 정보 행을 만드는 작은 헬퍼 위젯
  Widget _buildDetailRow({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[700], size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
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
                      //여기로
                      onTap: () async {
                        Navigator.pop(context);

                        if (schedule.location?.latitude == null || schedule.location?.longitude == null) {
                          return;
                        }

                        if (schedule.isEvent) {
                          _mapController?.setCenter(LatLng(
                            schedule.location!.latitude!,
                            schedule.location!.longitude!,
                          ));
                          _mapController?.setLevel(3);
                        }
                        // isEvent가 false이면 경로 그리기
                        else {
                          LatLng startLatLng;
                          final endLatLng = LatLng(schedule.location!.latitude!, schedule.location!.longitude!);

                          if (index == 0) {
                            startLatLng = _currentLocationMarker!.latLng;
                          }
                          else {
                            final previousSchedule = _schedules[index - 1];
                            if (previousSchedule.location?.latitude == null || previousSchedule.location?.longitude == null) {
                              return;
                            }
                            startLatLng = LatLng(previousSchedule.location!.latitude!, previousSchedule.location!.longitude!);
                          }

                          // 경로(polyline) 그리기
                          await _drawRoutePolyline(startLatLng, endLatLng);

                          List<LatLng> bounds = [startLatLng, endLatLng];
                          setState(() {
                            _mapController!.fitBounds(bounds);
                          });
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

  //카카오 Polyline을 가져오는 함수
  Future<List<LatLng>> getRoutePolyline(LatLng start, LatLng end) async {
    final String API_KEY = dotenv.env['KAKAO_REST_API_KEY'] ?? '';

    final queryParams = {
      'origin': '${start.longitude},${start.latitude}',
      'destination': '${end.longitude},${end.latitude}',
      'priority': 'RECOMMEND',
      'car_fuel': 'GASOLINE',
      'car_hipass': 'false',
    };

    try {
      final uri = Uri.https(
        'apis-navi.kakaomobility.com',
        '/v1/directions',
        queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'KakaoAK $API_KEY',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<LatLng> polylinePoints = [];

        if (data['routes'] != null && data['routes'] is List && data['routes'].isNotEmpty) {
          final firstRoute = data['routes'][0];
          final resultCode = firstRoute['result_code'];
          final resultMsg = firstRoute['result_msg'];
          print("API 결과 코드: $resultCode, 메시지: $resultMsg");

          final sections = firstRoute['sections'];
          if (sections != null && sections.isNotEmpty) {
            // 정상적으로 경로 처리
          } else {
            print("경로 없음: $resultMsg");
          }

          if (sections != null && sections is List && sections.isNotEmpty) {
            for (var section in sections) {
              final roads = section['roads'];
              if (roads != null && roads is List && roads.isNotEmpty) {
                for (var road in roads) {
                  final vertexes = road['vertexes'];
                  if (vertexes != null && vertexes is List && vertexes.isNotEmpty) {
                    for (int i = 0; i < vertexes.length; i += 2) {
                      polylinePoints.add(LatLng(vertexes[i + 1], vertexes[i]));
                    }
                  }
                }
              }
            }
          } else {
            print("경로 데이터 없음: sections 비어 있음");
          }
        } else {
          print("경로 데이터 없음: routes 비어 있음");
        }
        return polylinePoints;
      }else {
        print('경로 API 오류: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('경로 API 통신 오류: $e');
    }

    return [];
  }

  // polyline 지도에 표시
  Future<void> _drawRoutePolyline(LatLng pointA, LatLng pointB) async {
    // API를 통해 경로 데이터 가져오기
    final List<LatLng> points = await getRoutePolyline(pointA, pointB);

    if (points.isNotEmpty) {
      setState(() {
        _routePolyline = Polyline(
          polylineId: 'route_a_b',
          points: points,
          strokeColor: Colors.blueAccent,
          strokeOpacity: 0.9,
          strokeWidth: 10,
          strokeStyle: StrokeStyle.solid,
        );
      });
    } else {
      ToastUtils.showError('경로를 탐색할 수 없습니다.');
      setState(() {
        _routePolyline = null;
      });
    }
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
      } else if (travelMode == 'FOOT') {
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
          ToastUtils.showError('도보 길안내를 실행할 수 없습니다.');
        }
      } else if (travelMode == 'PUBLICTRANSIT') {
        // 대중교통 길안내 (카카오맵 URL 스킴 방식)
        // 대중교통 모드는 경유지를 지원하지 않으므로 현재 위치에서 목적지로 바로 이동
        try {
          Position? currentPosition;
          try {
            currentPosition = await Geolocator.getCurrentPosition();
          } catch (e) {
            print('현재 위치 가져오기 실패: $e');
          }

          final queryParameters = <String, String>{
            'ep': '${destination.latitude},${destination.longitude}',
            'by': 'PUBLICTRANSIT',
          };

          // 현재 위치가 있으면 출발지로 설정
          if (currentPosition != null) {
            queryParameters['sp'] = '${currentPosition.latitude},${currentPosition.longitude}';
          }

          final uri = Uri(
            scheme: 'kakaomap',
            host: 'route',
            queryParameters: queryParameters,
          );

          print('생성된 대중교통 길안내 URL: $uri');

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            // 카카오맵이 없으면 웹으로 열기
            final webUrl = 'https://map.kakao.com/link/to/${destination
                .name},${destination.latitude},${destination.longitude}';
            await launchUrl(Uri.parse(webUrl));
          }
        } catch (e) {
          print('대중교통 길안내 실패: $e');
          ToastUtils.showError('대중교통 길안내를 실행할 수 없습니다.');
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
          TextButton.icon(
            icon: const Icon(Icons.directions_transit, color: Colors.orange),
            label: Text(
              l10n.publicTransport,
              style: const TextStyle(color: Colors.orange),
            ),
            onPressed: () {
              Navigator.pop(context);
              _startKakaoNavi(location!, travelMode: 'PUBLICTRANSIT');
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
                polylines: [if (_routePolyline != null) _routePolyline!],
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
            bottom: 50, // WAVI 버튼과 겹치지 않도록 높이 조정
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

                            // 먼저 날짜와 상태를 설정
                            setState(() {
                              _selectedDate = pickedDate;
                              _showDateSchedules = true;
                            });
                            
                            // 그 다음 일정을 로드
                            await loadSchedules(forceShowDateSchedules: true);
                            allSchedules = [];
                            viaList = [];

                            if (_schedules.isNotEmpty) {
                              List<Schedule> newSchedules = [];

                              for (int i = 0; i < _schedules.length; i++) {
                                if (i % 2 != 0) {
                                  final schedule = _schedules[i];
                                  newSchedules.add(schedule);

                                  print('인덱스 $i (홀수): ${schedule.location!.name}, ${schedule.isEvent}');
                                }
                              }

                              // 출발지 추가
                              print('출발지: ${_currentLocationMarker!.latLng}');
                              allSchedules.add(Location(
                                  name: 'start',
                                  latitude: _currentLocationMarker!.latLng.latitude,
                                  longitude: _currentLocationMarker!.latLng.longitude
                              ));

                              // 경유지 및 도착지 처리
                              for (int i = 0; i < newSchedules.length; i++) {
                                var waypoint = newSchedules[i].location!;
                                var kakao = await to_kakao(waypoint);

                                if (i == newSchedules.length - 1) {
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
                              setState(() {
                                _routenavigation = true;
                              });
                            }

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
                          setState(() {
                            _showDateSchedules = value ?? false;
                          });
                          if (value ?? false) {
                            await loadSchedules(forceShowDateSchedules: true);
                            //await _drawRoutePolyline(_currentLocationMarker!.latLng, LatLng(allSchedules.last.latitude!,allSchedules.last.longitude!));

                                setState(() {
                              // 화면 조정
                              if (_mapController != null && allSchedules.isNotEmpty) {
                                List<LatLng> bounds = allSchedules.map((location) {
                                  return LatLng(location.latitude!, location.longitude!);
                                }).toList();

                                if (bounds.isNotEmpty) {
                                  _mapController!.fitBounds(bounds);
                                }
                              }
                              
                              if (finalDestination != null) {
                                _routenavigation = true;
                              }
                            });
                          } else {
                            await loadSchedules(); // 모든 일정 표시
                            setState(() {
                              _routenavigation = false;
                              _routePolyline = null;
                            });
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
                          const SizedBox(width: 70),
                          TextButton.icon(
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
                          if (finalDestination != null) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                _showTravelModeDialog(finalDestination!);
                              },
                              icon: Icon(Icons.directions, size: 16, color: Colors.green[700]),
                              label: Text(
                                '길찾기',
                                style: TextStyle(fontSize: 13, color: Colors.green[700]),
                              ),
                            ),
                          ],
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