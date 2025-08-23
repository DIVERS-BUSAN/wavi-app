import 'package:flutter/material.dart';
import '../models/schedule.dart';

class ColorPicker extends StatefulWidget {
  final ScheduleColor selectedColor;
  final Function(ScheduleColor) onColorSelected;

  const ColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late ScheduleColor _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.selectedColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('색상 선택'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: ScheduleColor.values.length,
          itemBuilder: (context, index) {
            final color = ScheduleColor.values[index];
            final isSelected = _selectedColor == color;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = color;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Color(color.colorValue),
                  shape: BoxShape.circle,
                  border: isSelected 
                      ? Border.all(color: Colors.black, width: 3)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onColorSelected(_selectedColor);
            Navigator.pop(context);
          },
          child: const Text('선택'),
        ),
      ],
    );
  }
}

class ColorSelector extends StatelessWidget {
  final ScheduleColor selectedColor;
  final Function(ScheduleColor) onColorChanged;

  const ColorSelector({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => ColorPicker(
            selectedColor: selectedColor,
            onColorSelected: onColorChanged,
          ),
        );
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '색상',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Color(selectedColor.colorValue),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(width: 12),
            Text(selectedColor.displayName),
            const Spacer(),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}