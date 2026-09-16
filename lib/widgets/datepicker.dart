
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

typedef OnDateRangeSelected = void Function(DateTimeRange? selectedRange);

class ReusableDatePickerWidget extends StatefulWidget {
  final OnDateRangeSelected onDateSelected;
  final Widget child;

  const ReusableDatePickerWidget({
    Key? key,
    required this.onDateSelected,
    required this.child,
  }) : super(key: key);

  @override
  State<ReusableDatePickerWidget> createState() =>
      _ReusableDatePickerWidgetState();
}

class _ReusableDatePickerWidgetState extends State<ReusableDatePickerWidget> {
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );


  void _openDatePicker() {
    DateTimeRange tempRange = _selectedRange;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF101624),
            title: const Text(
              'Select Date Range',
              style: TextStyle(color: Color(0xFFF9FAFB)),
            ),
            content: SizedBox(
              height: 400,
              width: 320,
              child: Theme(
                data: Theme.of(context).copyWith(
                  textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
                  ),
                ),
                child: SfDateRangePicker(
                  backgroundColor: const Color(0xFF101624),
                
                  yearCellStyle: DateRangePickerYearCellStyle(
                    textStyle: const TextStyle(color: Colors.white),
                  ),
                
                  headerStyle: const DateRangePickerHeaderStyle(
                    backgroundColor: Color(0xFF1E293B),
                    textAlign: TextAlign.center,
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  monthViewSettings: const DateRangePickerMonthViewSettings(
                    viewHeaderStyle: DateRangePickerViewHeaderStyle(
                      textStyle: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  monthCellStyle: DateRangePickerMonthCellStyle(
                    textStyle: const TextStyle(color: Colors.white),
                    todayTextStyle: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                    rangeTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),


                    weekendTextStyle: const TextStyle(color: Colors.white60),
                    disabledDatesTextStyle: const TextStyle(color: Colors.white24),
                    leadingDatesTextStyle: const TextStyle(color: Colors.white38),
                  ),
                  selectionColor: Colors.blueAccent,
                  startRangeSelectionColor: Colors.blueAccent,
                  endRangeSelectionColor: Colors.blueAccent,
                  rangeSelectionColor: Colors.blueAccent.withOpacity(0.35),
                  todayHighlightColor: Colors.blueAccent,
                  selectionTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  selectionMode: DateRangePickerSelectionMode.range,
                  initialSelectedRange: PickerDateRange(
                    _selectedRange.start,
                    _selectedRange.end,
                  ),
                  onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                    if (args.value is PickerDateRange) {
                      final range = args.value as PickerDateRange;
                      if (range.startDate != null) {
                        setDialogState(() {
                          tempRange = DateTimeRange(
                            start: range.startDate!,
                            end: range.endDate ?? range.startDate!,
                          );
                        });
                      }
                    }
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (!mounted) return;

                  setState(() => _selectedRange = DateTimeRange(
                    start: DateTime.now().subtract(const Duration(days: 30)),
                    end: DateTime.now(),
                  ));
                 widget.onDateSelected(null);
                },
                child: const Text('Clear', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (!mounted) return;
                  setState(() => _selectedRange = tempRange);
                  widget.onDateSelected(tempRange);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openDatePicker,
      child: widget.child,
    );
  }
}