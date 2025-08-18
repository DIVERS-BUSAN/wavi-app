class Schedule {
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final Location? location;
  final bool isAlarmEnabled;
  final DateTime? alarmDateTime;
  final bool isAiVoiceEnabled;
  final ScheduleColor color;
  final DateTime createdAt;
  final DateTime updatedAt;

  Schedule({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    this.location,
    this.isAlarmEnabled = false,
    this.alarmDateTime,
    this.isAiVoiceEnabled = false,
    this.color = ScheduleColor.blue,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'location': location?.toJson(),
      'isAlarmEnabled': isAlarmEnabled,
      'alarmDateTime': alarmDateTime?.millisecondsSinceEpoch,
      'isAiVoiceEnabled': isAiVoiceEnabled,
      'color': color.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dateTime: DateTime.fromMillisecondsSinceEpoch(json['dateTime']),
      location: json['location'] != null ? Location.fromJson(json['location']) : null,
      isAlarmEnabled: json['isAlarmEnabled'] ?? false,
      alarmDateTime: json['alarmDateTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['alarmDateTime'])
          : null,
      isAiVoiceEnabled: json['isAiVoiceEnabled'] ?? false,
      color: ScheduleColor.values.firstWhere(
        (c) => c.name == json['color'],
        orElse: () => ScheduleColor.blue,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
    );
  }

  Schedule copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    Location? location,
    bool? isAlarmEnabled,
    DateTime? alarmDateTime,
    bool? isAiVoiceEnabled,
    ScheduleColor? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      isAlarmEnabled: isAlarmEnabled ?? this.isAlarmEnabled,
      alarmDateTime: alarmDateTime ?? this.alarmDateTime,
      isAiVoiceEnabled: isAiVoiceEnabled ?? this.isAiVoiceEnabled,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Location {
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  Location({
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      name: json['name'],
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Location copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    return Location(
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

enum ScheduleColor {
  red('빨강', 0xFFE57373),
  pink('분홍', 0xFFF06292),
  purple('보라', 0xFFBA68C8),
  deepPurple('진보라', 0xFF9575CD),
  indigo('인디고', 0xFF7986CB),
  blue('파랑', 0xFF64B5F6),
  lightBlue('연파랑', 0xFF4FC3F7),
  cyan('청록', 0xFF4DD0E1),
  teal('청녹', 0xFF4DB6AC),
  green('초록', 0xFF81C784),
  lightGreen('연초록', 0xFFAED581),
  lime('라임', 0xFFDCE775),
  yellow('노랑', 0xFFFFF176),
  amber('호박', 0xFFFFD54F),
  orange('주황', 0xFFFFB74D),
  deepOrange('진주황', 0xFFFF8A65),
  brown('갈색', 0xFFA1887F),
  grey('회색', 0xFF90A4AE),
  blueGrey('청회색', 0xFF90CAF9);

  const ScheduleColor(this.displayName, this.colorValue);
  
  final String displayName;
  final int colorValue;
}