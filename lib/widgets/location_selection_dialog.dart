import 'package:flutter/material.dart';
import '../models/schedule.dart';

class LocationSelectionDialog extends StatefulWidget {
  final List<Location> locationOptions;
  final String originalLocationName;
  final Function(Location?) onLocationSelected;

  const LocationSelectionDialog({
    super.key,
    required this.locationOptions,
    required this.originalLocationName,
    required this.onLocationSelected,
  });

  @override
  State<LocationSelectionDialog> createState() => _LocationSelectionDialogState();
}

class _LocationSelectionDialogState extends State<LocationSelectionDialog> {
  Location? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.location_on, color: Colors.green[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '위치 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '검색어: "${widget.originalLocationName}"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '찾은 위치들 중에서 선택해주세요:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...widget.locationOptions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final location = entry.value;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedLocation == location 
                                ? Colors.green 
                                : Colors.grey[300]!,
                            width: _selectedLocation == location ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: _selectedLocation == location 
                              ? Colors.green[50] 
                              : Colors.white,
                        ),
                        child: RadioListTile<Location>(
                          value: location,
                          groupValue: _selectedLocation,
                          onChanged: (Location? value) {
                            setState(() {
                              _selectedLocation = value;
                            });
                          },
                          activeColor: Colors.green,
                          title: Text(
                            location.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _selectedLocation == location 
                                  ? Colors.green[700] 
                                  : Colors.black87,
                            ),
                          ),
                          subtitle: location.address != null
                              ? Text(
                                  location.address!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                )
                              : null,
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _selectedLocation == location 
                                  ? Colors.green[100] 
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedLocation == location 
                                    ? Colors.green[700] 
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '위치 없이 저장',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '위에 원하는 위치가 없다면, 위치 정보 없이 일정만 저장할 수 있습니다.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(null);
          },
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedLocation);
          },
          child: Text(
            _selectedLocation != null ? '선택' : '위치 없이 저장',
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}