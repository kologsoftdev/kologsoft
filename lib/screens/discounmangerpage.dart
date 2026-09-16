
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/discountmanager.dart';
import '../providers/Datafeed.dart';

import '../widgets/salespagewidgets/decorateinput.dart';
import '../widgets/salespagewidgets/snackmsg.dart';
import 'discountmangerpagview.dart';

class DiscountCodeRegisterPage extends StatefulWidget {
  const DiscountCodeRegisterPage({super.key});

  @override
  State<DiscountCodeRegisterPage> createState() => _DiscountCodeRegisterPageState();
}

class _DiscountCodeRegisterPageState extends State<DiscountCodeRegisterPage> {
  final _formKey        = GlobalKey<FormState>();
  final _amountCtrl     = TextEditingController();
  final _nameController = TextEditingController();

  String    _generatedCode = '';
  DateTime? _expiryDate;
  bool      _isSaving      = false;

  String? _savedCode;
  double? _savedAmount;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng   = Random.secure();
    String code;
    do {
      code = List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
    } while (context.read<Datafeed>().discountCodeExists(code));
    setState(() => _generatedCode = code);
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 365)),
      builder:     (_, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.blue,
            surface: Color(0xFF1B263B),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    snackMsg(context,'"$code" copied to clipboard', Colors.green);

  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final datafeed = context.read<Datafeed>();

    if (datafeed.discountCodeExists(_generatedCode)) {
      _generateCode();
      snackMsg(context,'Code regenerated — try saving again.', Colors.red);
      return;
    }

    setState(() {
      _isSaving    = true;
      _savedCode   = null;
      _savedAmount = null;
    });

    final amount = double.parse(_amountCtrl.text.trim());
    final now = DateTime.now();
    final day = DateFormat('EEEE').format(now);
    final year = now.year.toString();
    final month = '${now.year}.${now.month}';
    final weekNumber =
        ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;

    final week = '${now.year}.$weekNumber';
    final dc = DiscountCodeModel(
      id:          _generatedCode,
      companyId:   datafeed.companyid,
      companyName: datafeed.company,
      name:        _nameController.text.trim(),
      staff:       datafeed.staff,
      branch:      datafeed.branch,
      code:        _generatedCode,
      amount:      amount,
      createdBy:   datafeed.staff,
      createdAt:   Timestamp.now(),
      expiresAt:   _expiryDate != null
          ? Timestamp.fromDate(_expiryDate!)
          : null,
      day: day,
      week: week,
      month: month,
      year: year,
    );

    final ok = await datafeed.saveDiscountCode(dc);
    if (!mounted) return;

    if (ok) {
      _amountCtrl.clear();
      _nameController.clear();
      setState(() {
        _isSaving    = false;
        _expiryDate  = null;
        _savedCode   = dc.code;
        _savedAmount = dc.amount;
      });
      _generateCode();
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to save. Try again.'),
        backgroundColor: Colors.red,
      ));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        title: const Text(
          'Create Discount Code',
          style: TextStyle(
            color:         Colors.white,
            fontSize:      16,
            fontWeight:    FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        centerTitle:     true,
        backgroundColor: const Color(0xFF1B263B),
        iconTheme:       const IconThemeData(color: Colors.white),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  if (_savedCode != null) ...[
                    Container(
                      width:   double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        color:        Colors.green.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.green.withOpacity(0.45),
                            width: 1.2),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.check_circle_outline,
                                  color: Colors.greenAccent, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Saved — hand this code to the sales person',
                                style: TextStyle(
                                    color:      Colors.greenAccent,
                                    fontSize:   12,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _savedCode!,
                            style: const TextStyle(
                              color:         Colors.white,
                              fontSize:      36,
                              fontWeight:    FontWeight.bold,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'GHS ${_savedAmount!.toStringAsFixed(2)} discount',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 160,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 11),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              icon:  const Icon(Icons.copy, size: 16),
                              label: const Text('Copy Code',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize:   13)),
                              onPressed: () => _copy(_savedCode!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  TextFormField(
                    controller: _amountCtrl,
                    cursorColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*$')),
                    ],
                    decoration: decorationInput(
                      'Discount Amount',
                      hint:   'Fixed GHS amount to deduct from sale total',
                      prefix: 'GHS  ',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter the GHS amount';
                      }
                      final val = double.tryParse(v.trim());
                      if (val == null || val <= 0) {
                        return 'Must be greater than zero';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: _pickExpiry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color:        const Color(0xFF22304A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _expiryDate != null
                              ? Colors.orangeAccent.withOpacity(0.6)
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                          children: [
                        Icon(Icons.calendar_today,
                            color: _expiryDate != null
                                ? Colors.blue
                                : Colors.white54,
                            size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _expiryDate != null
                                ? 'Expires: ${_formatDate(_expiryDate!)}'
                                : 'Expiry date (optional — tap to set)',
                            style: TextStyle(
                              color: _expiryDate != null
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_expiryDate != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _expiryDate = null),
                            child: const Icon(Icons.close,
                                color: Colors.white38, size: 18),
                          ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.blue.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: const [
                      Icon(Icons.info_outline,
                          color: Colors.blueAccent, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This code works once. Hand it to a sales person — '
                              'when entered at the sales page the GHS amount is '
                              'deducted and the code immediately expires.',
                          style: TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Wrap(
                      spacing:    12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 200,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF415A77),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12)),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                width:  18,
                                height: 18,
                                child:  CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                                : const Icon(Icons.save_outlined,
                                size: 20, color: Colors.white70),
                            label: Text(
                              _isSaving ? 'Saving...' : 'Save Discount Code',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize:   15,
                                  color:      Colors.white70),
                            ),
                            onPressed: _isSaving ? null : _save,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Colors.white70),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.view_list,
                                color: Colors.white70),
                            label: const Text('View',
                                style:
                                TextStyle(color: Colors.white70)),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      DiscountCodeListPage()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
}