import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/location_picker.dart';
import '../widgets/color_picker.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../services/notification_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  late final ValueNotifier<List<Schedule>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Schedule>> _events = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadSchedules();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<Schedule> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    final schedules = await _scheduleService.getAllSchedules();
    
    // 일정을 날짜별로 그룹핑
    final Map<DateTime, List<Schedule>> events = {};
    for (final schedule in schedules) {
      final date = DateTime(
        schedule.dateTime.year,
        schedule.dateTime.month,
        schedule.dateTime.day,
      );
      
      if (events[date] == null) {
        events[date] = [];
      }
      events[date]!.add(schedule);
    }
    
    setState(() {
      _events = events;
      _isLoading = false;
    });

    // 선택된 날의 이벤트 업데이트
    _selectedEvents.value = _getEventsForDay(_selectedDay!);
  }

  Future<void> _deleteSchedule(String id) async {
    // 알림도 함께 취소
    await NotificationService().cancelNotification(id);
    
    final success = await _scheduleService.deleteSchedule(id);
    if (success) {
      _loadSchedules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정이 삭제되었습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(title: '일정'),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildCalendar(),
                  const SizedBox(height: 8.0),
                  Expanded(child: _buildEventList()),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddScheduleDialog(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TableCalendar<Schedule>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        eventLoader: _getEventsForDay,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: _onDaySelected,
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
          ),
          formatButtonTextStyle: TextStyle(
            color: Colors.white,
          ),
        ),
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: Colors.red),
          holidayTextStyle: TextStyle(color: Colors.red),
          selectedDecoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            if (events.isNotEmpty) {
              return Positioned(
                right: 1,
                bottom: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: events.take(3).map((event) {
                    return Container(
                      margin: const EdgeInsets.only(right: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Color((event as Schedule).color.colorValue),
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                ),
              );
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildEventList() {
    return ValueListenableBuilder<List<Schedule>>(
      valueListenable: _selectedEvents,
      builder: (context, events, _) {
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedDay != null 
                      ? '${DateFormat('MM월 dd일').format(_selectedDay!)}에\n등록된 일정이 없습니다'
                      : '날짜를 선택하여 일정을 확인하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final schedule = events[index];
            return _buildScheduleCard(schedule);
          },
        );
      },
    );
  }

  Widget _buildScheduleCard(Schedule schedule) {
    final isUpcoming = schedule.dateTime.isAfter(DateTime.now());
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showScheduleDetail(schedule),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(schedule.color.colorValue),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('HH:mm').format(schedule.dateTime),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (schedule.isAlarmEnabled) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.alarm,
                                size: 14,
                                color: Colors.blue[600],
                              ),
                            ],
                          ],
                        ),
                        if (schedule.location != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.red[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  schedule.location!.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('수정'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('삭제', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteConfirmDialog(schedule.id);
                      } else if (value == 'edit') {
                        _showEditScheduleDialog(schedule);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showAddScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) => AddScheduleDialog(
        selectedDate: _selectedDay,
        onScheduleAdded: _loadSchedules,
      ),
    );
  }

  void _showEditScheduleDialog(Schedule schedule) {
    showDialog(
      context: context,
      builder: (context) => AddScheduleDialog(
        schedule: schedule,
        onScheduleAdded: _loadSchedules,
      ),
    );
  }

  void _showDeleteConfirmDialog(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('이 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSchedule(id);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showScheduleDetail(Schedule schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(schedule.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('날짜: ${DateFormat('yyyy년 MM월 dd일 HH:mm').format(schedule.dateTime)}'),
            if (schedule.description != null)
              Text('내용: ${schedule.description}'),
            if (schedule.location != null) ...[
              Text('장소: ${schedule.location!.name}'),
              if (schedule.location!.address != null)
                Text('주소: ${schedule.location!.address}'),
            ],
            if (schedule.isAlarmEnabled)
              Text('알림: 설정됨'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

class AddScheduleDialog extends StatefulWidget {
  final Schedule? schedule;
  final DateTime? selectedDate;
  final VoidCallback onScheduleAdded;

  const AddScheduleDialog({
    super.key,
    this.schedule,
    this.selectedDate,
    required this.onScheduleAdded,
  });

  @override
  State<AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<AddScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ScheduleService _scheduleService = ScheduleService();
  final NotificationService _notificationService = NotificationService();

  DateTime _selectedDateTime = DateTime.now();
  bool _isAlarmEnabled = false;
  NotificationOption _selectedNotificationOption = NotificationService.notificationOptions[0];
  bool _isAiVoiceEnabled = false;
  Location? _selectedLocation;
  ScheduleColor _selectedColor = ScheduleColor.blue;

  @override
  void initState() {
    super.initState();
    if (widget.schedule != null) {
      _titleController.text = widget.schedule!.title;
      _descriptionController.text = widget.schedule!.description ?? '';
      _selectedDateTime = widget.schedule!.dateTime;
      _isAlarmEnabled = widget.schedule!.isAlarmEnabled;
      _isAiVoiceEnabled = widget.schedule!.isAiVoiceEnabled;
      _selectedLocation = widget.schedule!.location;
      _selectedColor = widget.schedule!.color;
      
      // 알림 설정 복원
      if (widget.schedule!.alarmDateTime != null) {
        final difference = widget.schedule!.dateTime.difference(widget.schedule!.alarmDateTime!).inMinutes;
        _selectedNotificationOption = NotificationService.notificationOptions
            .firstWhere((option) => option.minutesBefore == difference,
                orElse: () => NotificationService.notificationOptions[0]);
      }
    } else if (widget.selectedDate != null) {
      // 선택된 날짜로 초기화 (오늘 시간 설정)
      final now = DateTime.now();
      _selectedDateTime = DateTime(
        widget.selectedDate!.year,
        widget.selectedDate!.month,
        widget.selectedDate!.day,
        now.hour,
        now.minute,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  DateTime? _calculateAlarmDateTime() {
    if (!_isAlarmEnabled) return null;
    
    return _selectedDateTime.subtract(
      Duration(minutes: _selectedNotificationOption.minutesBefore)
    );
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    final alarmDateTime = _calculateAlarmDateTime();

    bool success;
    Schedule? savedSchedule;
    
    if (widget.schedule == null) {
      success = await _scheduleService.addSchedule(
        title: _titleController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        dateTime: _selectedDateTime,
        location: _selectedLocation,
        isAlarmEnabled: _isAlarmEnabled,
        alarmDateTime: alarmDateTime,
        isAiVoiceEnabled: _isAiVoiceEnabled,
        color: _selectedColor,
      );
      
      if (success) {
        // 새로 생성된 일정을 가져와서 알림 설정
        final schedules = await _scheduleService.getAllSchedules();
        savedSchedule = schedules.firstWhere((s) => 
          s.title == _titleController.text && 
          s.dateTime == _selectedDateTime
        );
      }
    } else {
      final updatedSchedule = widget.schedule!.copyWith(
        title: _titleController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        dateTime: _selectedDateTime,
        location: _selectedLocation,
        isAlarmEnabled: _isAlarmEnabled,
        alarmDateTime: alarmDateTime,
        isAiVoiceEnabled: _isAiVoiceEnabled,
        color: _selectedColor,
      );
      success = await _scheduleService.updateSchedule(updatedSchedule);
      savedSchedule = updatedSchedule;
      
      // 기존 알림 취소
      await _notificationService.cancelNotification(widget.schedule!.id);
    }

    // 알림 설정
    if (success && savedSchedule != null && _isAlarmEnabled) {
      await _notificationService.scheduleNotification(savedSchedule);
    }
    
    if (success && mounted) {
      Navigator.pop(context);
      widget.onScheduleAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.schedule == null 
              ? '일정이 추가되었습니다' 
              : '일정이 수정되었습니다'),
        ),
      );
    } else if (!success && mounted) {
      // 저장 실패 시 에러 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('일정 저장에 실패했습니다. 다시 시도해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.schedule == null ? '새 일정 추가' : '일정 수정'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '일정 제목 *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '제목을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '일정 설명',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectDateTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '날짜 및 시간 *',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      DateFormat('yyyy년 MM월 dd일 HH:mm').format(_selectedDateTime),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => LocationPicker(
                        initialLocation: _selectedLocation,
                        onLocationSelected: (location) {
                          setState(() {
                            _selectedLocation = location;
                          });
                        },
                      ),
                    );
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '장소',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.location_on),
                    ),
                    child: _selectedLocation != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedLocation!.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (_selectedLocation!.address != null)
                                Text(
                                  _selectedLocation!.address!,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          )
                        : const Text(
                            '장소를 선택하세요',
                            style: TextStyle(color: Colors.grey),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                ColorSelector(
                  selectedColor: _selectedColor,
                  onColorChanged: (color) {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('알림 설정'),
                  value: _isAlarmEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isAlarmEnabled = value ?? false;
                    });
                  },
                ),
                if (_isAlarmEnabled) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<NotificationOption>(
                    value: _selectedNotificationOption,
                    decoration: const InputDecoration(
                      labelText: '알림 시간',
                      border: OutlineInputBorder(),
                    ),
                    items: NotificationService.notificationOptions
                        .map((option) => DropdownMenuItem(
                              value: option,
                              child: Text(option.label),
                            ))
                        .toList(),
                    onChanged: (option) {
                      if (option != null) {
                        setState(() {
                          _selectedNotificationOption = option;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Row(
                      children: [
                        Icon(Icons.record_voice_over, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('AI 비서 음성 알림'),
                      ],
                    ),
                    subtitle: const Text(
                      'AI 비서가 일정 내용을 음성으로 알려드립니다',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: _isAiVoiceEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isAiVoiceEnabled = value ?? false;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _saveSchedule,
          child: Text(widget.schedule == null ? '추가' : '수정'),
        ),
      ],
    );
  }
}