import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/location_picker.dart';
import '../widgets/color_picker.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../services/notification_service.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/toast_utils.dart';


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
    _focusedDay = _selectedDay!;
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
      final startDate = DateTime(
        schedule.dateTime.year,
        schedule.dateTime.month,
        schedule.dateTime.day,
      );
      final endDate = DateTime(
        schedule.EnddateTime.year,
        schedule.EnddateTime.month,
        schedule.EnddateTime.day,
      );

      // 시작 날짜에 추가
      events.putIfAbsent(startDate, () => []);
      events[startDate]!.add(schedule);

      // 종료 날짜가 다르면 종료 날짜에도 추가
      if (endDate != startDate) {
        events.putIfAbsent(endDate, () => []);
        events[endDate]!.add(schedule);
      }
    }
    
    setState(() {
      _events = events;
      _isLoading = false;
    });
    print("📌 _events keys: ${_events.keys}");
    print("📌 $_selectedDay 의 일정: ${_getEventsForDay(_selectedDay!).map((e)=>e.toJson()).toList()}");

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
        final l10n = AppLocalizations.of(context);
        ToastUtils.showSuccess(l10n.scheduleDeleted);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: l10n.scheduleTab),
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
    final l10n = AppLocalizations.of(context);
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
                      ? '${DateFormat(context.read<LanguageProvider>().isEnglish ? 'MMM dd' : 'MM월 dd일').format(_selectedDay!)}${context.read<LanguageProvider>().isEnglish ? '\n' : '에\n'}${l10n.noSchedulesOnDate}'
                      : l10n.selectDateToViewSchedules,
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

        // 시간순 정렬
        final sortedEvents = List<Schedule>.from(events)
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 20, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat(context.read<LanguageProvider>().isEnglish ? 'EEEE, MMM dd yyyy' : 'yyyy년 MM월 dd일 EEEE', context.read<LanguageProvider>().isEnglish ? 'en_US' : 'ko_KR').format(_selectedDay!),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.scheduleCount(sortedEvents.length),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sortedEvents.length,
                itemBuilder: (context, index) {
                  final schedule = sortedEvents[index];
                  final isFirst = index == 0;
                  final isLast = index == sortedEvents.length - 1;
                  
                  return _buildTimelineScheduleCard(
                    schedule: schedule,
                    index: index + 1,
                    isFirst: isFirst,
                    isLast: isLast,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineScheduleCard({
    required Schedule schedule,
    required int index,
    required bool isFirst,
    required bool isLast,
  }) {
    final isTravel = !schedule.isEvent; // 이동 일정 구분

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 타임라인 인디케이터
        Column(
          children: [
            if (!isFirst)
              Container(
                width: 2,
                height: 20,
                color: Colors.grey[300],
              ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isTravel ? Colors.orange : Color(schedule.color.colorValue),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: (isTravel ? Colors.orange : Color(schedule.color.colorValue))
                        .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: isTravel
                    ? const Icon(Icons.directions_car, color: Colors.white, size: 18) // 🚗 아이콘
                    : Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 80,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        // 일정 카드
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Card(
              color: isTravel ? Colors.orange.shade50 : null, // 이동 일정 배경 강조
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isTravel ? Colors.orange : Color(schedule.color.colorValue))
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${DateFormat('HH:mm').format(schedule.dateTime)} ~ ${DateFormat('HH:mm').format(schedule.EnddateTime)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isTravel ? Colors.orange : Color(schedule.color.colorValue),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (schedule.isAlarmEnabled)
                            Icon(Icons.alarm, size: 16, color: Colors.blue[600]),
                          const Spacer(),
                          if (!isTravel) // 🚫 이동 일정에는 수정/삭제 메뉴 제거
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit, size: 18),
                                      const SizedBox(width: 8),
                                      Text(AppLocalizations.of(context).edit),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete, size: 18, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Text(AppLocalizations.of(context).delete,
                                          style: const TextStyle(color: Colors.red)),
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
                      const SizedBox(height: 8),
                      Text(
                        isTravel ? "[이동] ${schedule.title}" : schedule.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isTravel ? Colors.orange[800] : Colors.black,
                        ),
                      ),
                      if (schedule.location != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 16,
                                color: isTravel ? Colors.orange[700] : Colors.red[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                schedule.location!.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (schedule.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          schedule.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 18),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context).edit),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context).delete, style: const TextStyle(color: Colors.red)),
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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSchedule),
        content: Text(l10n.deleteScheduleConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSchedule(id);
            },
            child: Text(l10n.delete),
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
            Text('${AppLocalizations.of(context).dateAndTime}: ${DateFormat(context.read<LanguageProvider>().isEnglish ? 'MMM dd yyyy HH:mm' : 'yyyy년 MM월 dd일 HH:mm').format(schedule.dateTime)}'),
            if (schedule.description != null)
              Text('${AppLocalizations.of(context).scheduleDescription}: ${schedule.description}'),
            if (schedule.location != null) ...[
              Text('${AppLocalizations.of(context).location}: ${schedule.location!.name}'),
              if (schedule.location!.address != null)
                Text('${AppLocalizations.of(context).location}: ${schedule.location!.address}'),
            ],
            if (schedule.isAlarmEnabled)
              Text('${AppLocalizations.of(context).alarmSettings}: ${AppLocalizations.of(context).aiVoiceAlarm}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).confirm),
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
  DateTime _selectedEndDateTime = DateTime.now();
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
      _selectedEndDateTime = widget.schedule!.EnddateTime;
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
      _selectedEndDateTime = _selectedDateTime.add(const Duration(hours: 1)); // ✅ 종료시간 기본값
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

  Future<void> _selectEndDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedEndDateTime,
      firstDate: _selectedDateTime, // 시작시간 이후로 제한
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedEndDateTime),
      );

      if (time != null) {
        setState(() {
          _selectedEndDateTime = DateTime(
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
        EnddateTime: _selectedEndDateTime,
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
      ToastUtils.showSuccess(widget.schedule == null 
          ? AppLocalizations.of(context).scheduleAdded
          : AppLocalizations.of(context).scheduleUpdated);
    } else if (!success && mounted) {
      // 저장 실패 시 에러 메시지 표시
      ToastUtils.showError(AppLocalizations.of(context).saveScheduleFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.schedule == null ? l10n.newSchedule : l10n.editSchedule),
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
                  decoration: InputDecoration(
                    labelText: '${l10n.scheduleTitleField}${l10n.required}',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.enterTitle;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: l10n.scheduleDescription,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectDateTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '${l10n.dateAndTime}${l10n.required}',
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(
                      DateFormat(context.read<LanguageProvider>().isEnglish ? 'MMM dd yyyy HH:mm' : 'yyyy년 MM월 dd일 HH:mm').format(_selectedDateTime),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectEndDateTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '${l10n.dateAndTime}${l10n.required}',
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(
                      DateFormat(context.read<LanguageProvider>().isEnglish
                          ? 'MMM dd yyyy HH:mm'
                          : 'yyyy년 MM월 dd일 HH:mm'
                      ).format(_selectedEndDateTime),
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
                    decoration: InputDecoration(
                      labelText: l10n.location,
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.location_on),
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
                        : Text(
                            l10n.selectLocation,
                            style: const TextStyle(color: Colors.grey),
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
                  title: Text(l10n.alarmSettings),
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
                    decoration: InputDecoration(
                      labelText: l10n.alarmTime,
                      border: const OutlineInputBorder(),
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
                    title: Row(
                      children: [
                        const Icon(Icons.record_voice_over, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.aiVoiceAlarm),
                      ],
                    ),
                    subtitle: Text(
                      l10n.aiVoiceAlarmDescription,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _saveSchedule,
          child: Text(widget.schedule == null ? l10n.add : l10n.edit),
        ),
      ],
    );
  }
}