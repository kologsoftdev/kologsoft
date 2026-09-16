import 'package:flutter/material.dart';
import 'package:kologsoft/models/paymentdurationmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../providers/routes.dart';

class PaymentDurationReg extends StatefulWidget {
  final PaymentDurationModel? payment;
  const PaymentDurationReg({super.key, this.payment});

  @override
  State<PaymentDurationReg> createState() => _PaymentDurationRegState();
}

class _PaymentDurationRegState extends State<PaymentDurationReg> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _branchcontactController = TextEditingController();

  String? _selectedPaymentName;
  final List<String> _durationName = ['Long Term', 'Short Term'];

  @override
  void initState() {
    super.initState();

    if (widget.payment != null) {
      _durationController.text = widget.payment!.duration;
      _selectedPaymentName = widget.payment!.paymentname;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
        builder: (BuildContext context, Datafeed value, Widget? child){
          return Scaffold(
            backgroundColor: const Color(0xFF101A23),
            appBar: AppBar(
              title: Text(widget.payment != null ? "EDIT PAYMENT DURATION" : "PAYMENT DURATION REGISTRATION"),
              backgroundColor: const Color(0xFF0D1A26),
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 700
                  ),
                  child: Form(
                    key: _formKey,
                      child: ListView(
                        children: [
                          Card(
                            color: const Color(0xFF182232),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0, top: 20, right: 16, bottom: 20),
                              child: Column(children: [
                                DropdownButtonFormField<String>(
                                  value: _selectedPaymentName,
                                  dropdownColor: const Color(0xFF22304A),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Payment Name',
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Colors.white24),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Colors.blue),
                                    ),
                                    fillColor: const Color(0xFF22304A),
                                    filled: true,
                                  ),
                                  items: _durationName.map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(type),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPaymentName = value;
                                    });
                                  },
                                  validator: (value) =>
                                  value == null ? 'Please select payment name' : null,
                                ),

                                SizedBox(height: 14),
                                TextFormField(
                                  controller: _durationController,
                                  style: TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Payment Duration',
                                    labelStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.blue,
                                      ),
                                    ),
                                    fillColor: const Color(0xFF22304A),
                                    filled: true,
                                  ),
                                  validator: (value) => value == null || value.isEmpty
                                      ? 'Enter payment duration'
                                      : null,
                                ),
                                const SizedBox(height: 30),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    // Save button
                                    SizedBox(
                                      width: 200,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        onPressed: () async {
                                          if (!_formKey.currentState!.validate()) return;

                                          try {
                                            final payment = PaymentDurationModel(
                                              id: widget.payment?.id ?? '',
                                              duration: _durationController.text.trim(),
                                              paymentname: _selectedPaymentName!,
                                              staff: '',
                                              companyid: value.companyid,
                                              companyemail: value.companyemail,
                                              date: DateTime.now(),
                                              updatedat: DateTime.now(),
                                              deletedat: DateTime.now(),
                                              updatedby: '',
                                              deletedby: '',
                                            );

                                            await value.addOrUpdatePaymentDuration(payment);

                                            if (widget.payment != null) {
                                              Navigator.pop(context);
                                            }

                                            _durationController.clear();
                                            _branchcontactController.clear();
                                            setState(() => _selectedPaymentName = null);

                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(widget.payment != null
                                                    ? 'Payment duration updated successfully'
                                                    : 'Payment duration saved successfully'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Operation failed: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },

                                        child: Text(
                                          widget.payment != null ? "Update" : "Add",
                                          style: TextStyle(color: Colors.white),),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 200,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.white70),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        icon: const Icon(Icons.view_list, color: Colors.white70),
                                        label: const Text("View", style: TextStyle(color: Colors.white70)),
                                        onPressed: () {
                                          Navigator.pushNamed(context, Routes.paymentdurationview);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              ),
                            ),

                          )
                        ],
                      )
                  ),
                ),
              ),
            ),
          );
        }
    );
  }
}
