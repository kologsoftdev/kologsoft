import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/momo_payment_model.dart';
import '../providers/Datafeed.dart';
import '../providers/SalesProvider.dart';

class MomoDialog {

  static Future<Map<String, dynamic>?> showMomo({
    required BuildContext context,
   // dynamic calculateTaxableTotal,
    required List salesItems,
    Future<bool> Function()? validateCartStockOnSave,
  }) async {


    final datafeed = Provider.of<Datafeed>(context, listen: false);
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    bool isSaving = false;
    String? selectedNetwork;

    final allowed = datafeed.allowedPaymentMethods.map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty).toSet();
    // If not configured on staff, allow legacy behavior.
    if (allowed.isNotEmpty && !allowed.contains('momo')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MOMO payment is not enabled for this user.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
    if (!await salesProvider.validateCartStockOnSave( context,salesItems,datafeed,)) return null;

    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController amountController = TextEditingController( text: salesProvider.calculateTaxableTotal().toStringAsFixed(2),
    );
    if (salesItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items first'),
        ),
      );
      return null;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isDesktopLike = screenWidth >= 900;
          final dialogWidth = isDesktopLike
              ? screenWidth * 0.40
              : screenWidth * 0.95;
          final maxHeightFactor = isDesktopLike ? 0.75 : 0.90;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isDesktopLike ? 40 : 12,
              vertical: isDesktopLike ? 24 : 12,
            ),
            child: Container(
              width: dialogWidth,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.phone_android, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          'Mobile Money Payment',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Details',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22304A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedNetwork,
                                isExpanded: true,
                                hint: const Text(
                                  'Select Network',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                dropdownColor: const Color(0xFF22304A),
                                style: const TextStyle(color: Colors.white),
                                items: ['MTN', 'Vodafone', 'AirtelTigo'].map((network) => DropdownMenuItem<String>(
                                    value: network,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.sim_card,
                                          color: network == 'MTN'
                                              ? Colors.yellow
                                              : network == 'Vodafone'
                                              ? Colors.red
                                              : Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(network),
                                      ],
                                    ),
                                  ),
                                )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedNetwork = value;
                                  });
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Customer Name',
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                              prefixIcon: const Icon(
                                Icons.person,
                                color: Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF22304A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                              prefixIcon: const Icon(
                                Icons.phone,
                                color: Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF22304A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: amountController,
                            readOnly: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              prefixText: 'GHS ',
                              prefixStyle: const TextStyle(
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF22304A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[300],
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'A payment request will be sent to this number',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isSaving ? null
                              : () async {
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter customer name',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (phoneController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter phone number',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (selectedNetwork == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select network'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            setState(() => isSaving = true);

                            try {
                              final provider = Provider.of<Datafeed>(
                                context,
                                listen: false,
                              );

                              final docId = datafeed.db .collection('momo_payments').doc().id;

                              final momoPayment = MomoPaymentModel(
                                id: docId,
                                phoneNumber: phoneController.text,
                                amount: double.parse(amountController.text, ),
                                branchId: provider.selectedBranch?.id ?? '',
                                branchName: provider.selectedBranch?.branchname ??  '',
                                companyId: provider.companyid,
                                staff: provider.staff,
                                status: 'pending',
                                createdAt: DateTime.now(),
                              );

                              await datafeed.db.collection('momo_payments').doc(docId)
                                  .set({
                                ...momoPayment.toMap(),
                                'customerName': nameController.text.trim(),
                                'network': selectedNetwork,
                              });

                              if (context.mounted) {
                                Navigator.pop(context);

                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'MOMO request sent to ${phoneController.text}',
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color( 0xFF4CAF50,),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        10,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              setState(() => isSaving = false);

                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: isSaving
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send, size: 18),
                              SizedBox(width: 8),
                              Text('Send Request',style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

  }

}