import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import 'closesalesview.dart';

class CloseSalesPage extends StatefulWidget {
  final String? docId;
  final List<Map<String, dynamic>>? item;

  const CloseSalesPage({ super.key, this.docId, this.item,  });

  @override
  State<CloseSalesPage> createState() => _CloseSalesPageState();
}

class _CloseSalesPageState extends State<CloseSalesPage> {
  late List<TextEditingController> _quantityControllers;

  int? _editingRecordIndex;
  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    if (_isInitialized) {
      for (final controller in _quantityControllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _initializeControllers(Datafeed data) {
    _quantityControllers = List.generate(
      data.denominations.length,
          (_) => TextEditingController(),
    );


    if (widget.item != null && widget.item!.isNotEmpty) {
      for (int i = 0; i < widget.item!.length; i++) {

        final item = widget.item![i];
        final qty = item['quantity'] ?? 0;

        if (i < _quantityControllers.length) {
          _quantityControllers[i].text = qty.toString();
          data.updateCount(i, qty.toString());
        }
      }
    }
    else {

      for (var i = 0; i < data.denominations.length; i++) {
        _quantityControllers[i].text =
            data.denominations[i].count.toString();
      }
    }
  }



  void _clearForm(Datafeed data) {
    for (var i = 0; i < data.denominations.length; i++) {
      _quantityControllers[i].clear();
      data.updateCount(i, '0');
    }

    setState(() {
      _editingRecordIndex = null;
    });
  }

  Future<void> _saveRecord(Datafeed data) async {
    try {
      final money = data.denominations.map((e) {
        return {
          'denomination': e.value,
          'quantity': e.count,
          'total': e.value * e.count,
        };
      }).toList();

      // Check if everything is zero
      final isAllZero = money.every(
            (e) => e['quantity'] == 0,
      );

      if (isAllZero) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter at least one denomination.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );

        return;
      }

      // ----------------------------------------------------------
      // EDIT EXISTING RECORD
      // ----------------------------------------------------------
      if (widget.docId != null && widget.docId!.isNotEmpty) {
        await data.editCloseSale(
          docId: widget.docId!,
          money: money,
          total: data.total,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Record updated successfully.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // ----------------------------------------------------------
      // CREATE NEW RECORD
      // ----------------------------------------------------------
      else {
        await data.saveCloseSale(
          money: money,
          total: data.total,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Record saved successfully.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Reset form
      _clearForm(data);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving record: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(builder: (context, data, child) {
      if (!_isInitialized ||
          _quantityControllers.length != data.denominations.length) {
        _initializeControllers(data);
        _isInitialized = true;
      }

      final theme = Theme.of(context);
      return Scaffold(
        appBar: AppBar(
          title: const Text("Close Sale"),
          backgroundColor: const Color(0xFF0D1A26),
        ),
        backgroundColor: const Color(0xFF101624),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;
            final cardPadding = const EdgeInsets.all(10);
            final cardShape = RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            );

            final leftCard = Card(
              color: const Color(0xFF141C34),
              elevation: 1,
              shadowColor: Colors.black45,
              shape: cardShape,
              child: Padding(
                padding: cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...List.generate(
                      data.denominations.length,
                          (index) {
                        final item = data.denominations[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: isWide ? 110 : 90,
                                child: Text(
                                  index < 3
                                      ? '${item.value}p *'
                                      : 'GHC ${item.value} *',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _quantityControllers[index],
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],

                                  cursorColor: Colors.white70,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF1B253F),
                                    hintText: 'Enter count',
                                    hintStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFF334566)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFF334566)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: theme.colorScheme.primary),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    data.updateCount(index, val.isEmpty ? '0' : val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [

                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving
                                ? null
                                : () async {
                              setState(() => _isSaving = true);

                              await _saveRecord(data);

                              if (mounted) {
                                setState(() => _isSaving = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : Text(
                              _editingRecordIndex != null
                                  ? 'Update Record'
                                  : 'Save Record',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CloseSalesViewPage()),
                              );

                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: theme.colorScheme.onSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'View Records',
                              style: TextStyle(fontSize: 16,color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            final rightCard = Card(
              color: const Color(0xFF141C34),
              elevation: 1,
              shadowColor: Colors.black45,
              shape: cardShape,
              child: Padding(
                padding: cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLOSE SALES',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isWide)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                for (var i = 0; i < data.denominations.length; i++)
                                  Container(
                                    width: 80,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Text(
                                      i < 4
                                          ? '${data.denominations[i].value}p'
                                          : 'GHS\n${data.denominations[i].value}',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                Container(
                                  width: 90,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                    'TOTAL',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: theme.colorScheme.outline),
                            Row(
                              children: [
                                for (var index = 0;
                                index < data.denominations.length;
                                index++)
                                  Container(
                                    width: 80,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Text(
                                      data.getDenominationTotal(index).toString(),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                    ),
                                  ),
                                Container(
                                  width: 90,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Text(
                                    data.total.toString(),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (var index = 0;
                          index < data.denominations.length;
                          index++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      index < 3
                                          ? '${data.denominations[index].value}p'
                                          : 'GHS ${data.denominations[index].value}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      data.getDenominationTotal(index).toString(),
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(color: Color(0xFF334566)),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'TOTAL',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    data.total.toString(),
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: isWide
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: 1,
                      child: leftCard
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                      flex: 3,
                      child: rightCard
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leftCard,
                  const SizedBox(height: 20),
                  rightCard,
                ],
              ),
            );
          }),
        ),
      );
    });
  }
}