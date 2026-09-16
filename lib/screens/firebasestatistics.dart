import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FirebaseUsagePage extends StatefulWidget {
  const FirebaseUsagePage({super.key});

  @override
  State<FirebaseUsagePage> createState() => _FirebaseUsagePageState();
}

class _FirebaseUsagePageState extends State<FirebaseUsagePage> {
  DateTime _startDate = DateTime.now().subtract(
    const Duration(days: 1),
  );

  DateTime _endDate = DateTime.now();

  int _reads = 0;
  int _writes = 0;
  int _deletes = 0;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    setState(() {
      _loading = true;
    });

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('getFirebaseUsage');

      final result = await callable.call({
        'startDate': _startDate.toUtc().toIso8601String(),
        'endDate': _endDate.toUtc().toIso8601String(),
      });

      final data = Map<String, dynamic>.from(result.data);

      if (!mounted) return;

      setState(() {
        _reads = _toInt(data['reads']);
        _writes = _toInt(data['writes']);
        _deletes = _toInt(data['deletes']);
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Unable to load Firebase usage.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int get _totalOperations {
    return _reads + _writes + _deletes;
  }

  String _formatNumber(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }

    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101624),
        title: const Text(
          'Firebase Usage',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsage,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateFilter(),

              const SizedBox(height: 20),

              if (_loading)
                const LinearProgressIndicator(),

              const SizedBox(height: 20),

              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 12.0;
                  const minCardWidth = 220.0;

                  final columns = (constraints.maxWidth /
                      (minCardWidth + spacing))
                      .floor()
                      .clamp(1, 4);

                  final cardWidth =
                      (constraints.maxWidth -
                          ((columns - 1) * spacing)) /
                          columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _usageCard(
                          title: 'Total Reads',
                          value: _reads,
                          icon: Icons.visibility_outlined,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _usageCard(
                          title: 'Total Writes',
                          value: _writes,
                          icon: Icons.edit_outlined,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _usageCard(
                          title: 'Total Deletes',
                          value: _deletes,
                          icon: Icons.delete_outline,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _usageCard(
                          title: 'Total Operations',
                          value: _totalOperations,
                          icon: Icons.analytics_outlined,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 25),

              _buildSummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 180,
            maxWidth: 250,
          ),
          child: _dateButton(
            label: 'From',
            date: _startDate,
            onPressed: () => _pickDate(true),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 180,
            maxWidth: 250,
          ),
          child: _dateButton(
            label: 'To',
            date: _endDate,
            onPressed: () => _pickDate(false),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _loadUsage,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime date,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(
          color: Colors.white24,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${date.day.toString().padLeft(2, '0')}/'
                '${date.month.toString().padLeft(2, '0')}/'
                '${date.year}',
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
        );
      } else {
        _endDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
      }
    });

    await _loadUsage();
  }

  Widget _usageCard({
    required String title,
    required int value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF182232),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white70,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _formatNumber(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF182232),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Usage Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 20),

          _summaryRow(
            'Reads',
            _reads,
          ),

          _summaryRow(
            'Writes',
            _writes,
          ),

          _summaryRow(
            'Deletes',
            _deletes,
          ),

          const Divider(
            color: Colors.white12,
            height: 30,
          ),

          _summaryRow(
            'Total Operations',
            _totalOperations,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
      String title,
      int value, {
        bool bold = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white70,
                fontWeight:
                bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight:
              bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool bold;

  const _TableCell(
      this.text, {
        this.bold = false,
      });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white10,
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight:
          bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

class _UsageChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final int maxValue;

  _UsageChartPainter({
    required this.data,
    required this.maxValue,
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;

    // Horizontal grid lines.
    for (int i = 0; i < 5; i++) {
      final y = size.height * i / 4;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    if (data.length < 2 || maxValue == 0) {
      return;
    }

    _drawLine(
      canvas,
      size,
      data,
      'reads',
      maxValue,
      paint,
      Colors.blueAccent,
    );

    _drawLine(
      canvas,
      size,
      data,
      'writes',
      maxValue,
      paint,
      Colors.orangeAccent,
    );

    _drawLine(
      canvas,
      size,
      data,
      'deletes',
      maxValue,
      paint,
      Colors.redAccent,
    );
  }

  void _drawLine(
      Canvas canvas,
      Size size,
      List<Map<String, dynamic>> data,
      String key,
      int maxValue,
      Paint paint,
      Color color,
      ) {
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();

    for (int i = 0; i < data.length; i++) {
      final value = (data[i][key] ?? 0) as num;

      final double x = data.length == 1
          ? 0.0
          : size.width * i / (data.length - 1);

      final double y = size.height -
          (value.toDouble() / maxValue.toDouble()) *
              size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(
      covariant _UsageChartPainter oldDelegate,
      ) {
    return oldDelegate.data != data ||
        oldDelegate.maxValue != maxValue;
  }
}