import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/schedule.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class LocationPicker extends StatefulWidget {
  final Location? initialLocation;
  final Function(Location?) onLocationSelected;

  const LocationPicker({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  List<KakaoPlace> _searchResults = [];
  bool _isSearching = false;
  bool _isManualMode = false;
  Location? _selectedLocation;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _nameController.text = widget.initialLocation!.name;
      _addressController.text = widget.initialLocation!.address ?? '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    final String restApiKey = dotenv.env['KAKAO_REST_API_KEY']! ?? '';

    final String url = 'https://dapi.kakao.com/v2/local/search/keyword.json?query=$query';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'KakaoAK $restApiKey',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> documents = data['documents'];

        // API 결과에서 최대 5개의 장소를 가져옵니다.
        final List<KakaoPlace> places = documents
            .take(5)
            .map((item) => KakaoPlace.fromJson(item))
            .toList();

        setState(() {
          _searchResults = places;
          _isSearching = false;
        });
      } else {
        // API 호출 실패 시 에러 처리
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        print('Failed to load places: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      print('Error searching places: $e');
    }
  }
  void _selectPlace(KakaoPlace place) {
    final location = Location(
      name: place.placeName,
      address: place.roadAddressName ?? place.addressName,
      latitude: double.tryParse(place.y),
      longitude: double.tryParse(place.x),
    );

    setState(() {
      _selectedLocation = location;
      _nameController.text = location.name;
      _addressController.text = location.address ?? '';
      _searchResults = [];
      _searchController.clear();
    });
  }

  void _saveManualLocation() {
    if (_nameController.text.trim().isEmpty) return;

    final location = Location(
      name: _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
    );

    setState(() {
      _selectedLocation = location;
    });

    widget.onLocationSelected(location);
    Navigator.pop(context);
  }

  void _clearLocation() {
    setState(() {
      _selectedLocation = null;
      _nameController.clear();
      _addressController.clear();
      _searchController.clear();
      _searchResults = [];
    });
    widget.onLocationSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '장소 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isManualMode = !_isManualMode;
                          _searchResults = [];
                          _searchController.clear();
                        });
                      },
                      child: Text(_isManualMode ? '검색으로' : '직접입력'),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),

            if (!_isManualMode) ...[
              // 검색 모드
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '장소명을 입력하세요',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () => _searchController.clear(),
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                ),
                onChanged: (value) {
                  if (value.length > 1) {
                    _searchPlaces(value);
                  } else {
                    setState(() => _searchResults = []);
                  }
                },
              ),
              const SizedBox(height: 16),

              if (_isSearching)
                const Center(child: CircularProgressIndicator())
              else if (_searchResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final place = _searchResults[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.red),
                        title: Text(place.placeName),
                        subtitle: Text(place.roadAddressName ?? place.addressName),
                        onTap: () => _selectPlace(place),
                      );
                    },
                  ),
                ),
            ] else ...[
              // 직접 입력 모드
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '장소명 *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '주소',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveManualLocation,
                      child: const Text('저장'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearLocation,
                      child: const Text('취소'),
                    ),
                  ),
                ],
              ),
            ],

            if (_selectedLocation != null) ...[
              const Divider(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          '선택된 장소',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedLocation!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_selectedLocation!.address != null)
                      Text(
                        _selectedLocation!.address!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              widget.onLocationSelected(_selectedLocation);
                              Navigator.pop(context);
                            },
                            child: const Text('확인'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _clearLocation,
                          child: const Text('삭제'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class KakaoPlace {
  final String placeName;
  final String addressName;
  final String? roadAddressName;
  final String x; // longitude
  final String y; // latitude

  KakaoPlace({
    required this.placeName,
    required this.addressName,
    this.roadAddressName,
    required this.x,
    required this.y,
  });

  factory KakaoPlace.fromJson(Map<String, dynamic> json) {
    return KakaoPlace(
      placeName: json['place_name'],
      addressName: json['address_name'],
      roadAddressName: json['road_address_name'],
      x: json['x'],
      y: json['y'],
    );
  }
}