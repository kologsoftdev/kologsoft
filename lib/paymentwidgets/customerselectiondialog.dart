
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customerreg_model.dart';
import '../providers/Datafeed.dart';
import '../providers/SalesProvider.dart';
import 'customerinfodialog.dart';

class CustomerSelectionDialog {
  static Future<Map<String, dynamic>?> showCustomerDialog({
    required BuildContext context,

  }) async {
    final datafeed = Provider.of<Datafeed>(context, listen: false);
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
   final salesItems = salesProvider.salesItems;

    if (salesItems.isEmpty) {
      salesProvider.showMessage(context, 'Please add items first', Colors.red);
      return null;
    }

    // Ensure customers are fetched
    await datafeed.fetchCustomers();

    // Pure filter function (returns MODEL, not MAP)
    List<CustomerRegModel> filterCustomers(
        List<CustomerRegModel> customers,
        String query,
        ) {
      if (query.trim().isEmpty) {
        return List<CustomerRegModel>.from(customers);
      }

      final q = query.trim().toLowerCase();

      return customers.where((c) {
        final name = (c.name ?? '').toLowerCase();
        final phone = (c.contact ).toLowerCase();
       // final email = (c.date ?? '').toLowerCase();

        return name.contains(q) ||
            phone.contains(q) ;
          //  email.contains(q);
      }).toList();
    }
    List<CustomerRegModel> filterByScope(
        List<CustomerRegModel> customers,
        String scope,
        ) {
      return customers.where((c) {
        if (c.companyid != datafeed.companyid) return false;
        if (scope == 'branch' && c.branchid != datafeed.branchid) return false;
        return true;
      }).toList();
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final dialogWidth = (size.width * 0.90).clamp(320.0, 720.0);
        final horizontalPad =
        ((size.width - dialogWidth) / 2).clamp(12.0, 60.0);
        final maxHeight = (size.height * 0.85).clamp(360.0, size.height);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
              horizontal: horizontalPad, vertical: 12),
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6F00), Color(0xFFFF9800)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.people, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Select Customer',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // BODY
                Expanded(
                  child: Padding(
                    padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Consumer<Datafeed>(
                      builder: (context, datafeed, _) {
                        final customers = datafeed.customerlist;

                        if (customers == null) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (customers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_off,
                                    size: 64,
                                    color: Colors.white38),
                                const SizedBox(height: 16),
                                const Text(
                                  'No customers found',
                                  style: TextStyle(
                                      color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    CustomerInfoDialog.show(
                                      context: context,
                                      activeBranchId:
                                      datafeed.activeBranchId,
                                    );
                                  },
                                  icon: const Icon(Icons.add,
                                      color: Colors.white70),
                                  label: const Text(
                                    'Add New Customer',
                                    style: TextStyle(
                                        color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        String query = '';
                        String scope = 'branch';
                        List<CustomerRegModel> filtered =
                        List.from(customers);

                        return StatefulBuilder(
                          builder: (context, setInnerState) {
                            // Always recompute filtered list
                            // filtered = filterCustomers(customers, query);
                            filtered = filterCustomers(
                              filterByScope(customers, scope),
                              query,
                            );
                            return Column(
                              children: [
                                // Company or branch
                                Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<String>(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text(
                                          'This Branch',
                                          style: TextStyle(color: Colors.white70, fontSize: 13),
                                        ),
                                        value: 'branch',
                                        groupValue: scope,
                                        activeColor: Colors.orange,
                                        onChanged: (v) => setInnerState(() => scope = v!),
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<String>(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text(
                                          'All Company',
                                          style: TextStyle(color: Colors.white70, fontSize: 13),
                                        ),
                                        value: 'company',
                                        groupValue: scope,
                                        activeColor: Colors.orange,
                                        onChanged: (v) => setInnerState(() => scope = v!),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // SEARCH FIELD
                                TextField(
                                  onChanged: (v) =>
                                      setInnerState(() {
                                        query = v;
                                      }),
                                  style: const TextStyle(
                                      color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText:
                                    'Search by name or phone',
                                    hintStyle: const TextStyle(
                                        color: Colors.white54),
                                    prefixIcon: const Icon(
                                        Icons.search,
                                        color: Colors.white70),
                                    filled: true,
                                    fillColor:
                                    const Color(0xFF22304A),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(
                                          12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // CUSTOMER LIST
                                Expanded(
                                  child: filtered.isEmpty
                                      ? const Center(
                                    child: Text(
                                      'No matches',
                                      style: TextStyle(
                                          color:
                                          Colors.white70),
                                    ),
                                  )
                                      : ListView.builder(
                                    itemCount:
                                    filtered.length,
                                    itemBuilder:  (context, index) {
                                      final customer =   filtered[index];

                                      final displayPhone = (customer.contact ).toString();

                                      final name =   (customer.name ?? '').trim();

                                      final initial = name.isEmpty ? 'U' : name[0].toUpperCase();

                                      return Card(
                                        color: const Color( 0xFF22304A),
                                        margin:const EdgeInsets.symmetric(vertical:  4),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor:  Colors.orange,
                                            child: Text(initial,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:FontWeight.bold
                                              ),
                                            ),
                                          ),
                                          title: Text( name,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Phone: $displayPhone',
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12),
                                              ),
                                              Text(
                                                'Credit Limit: ${customer.creditlimit ?? ''}',
                                                style: const TextStyle(
                                                    color: Colors
                                                        .white70,
                                                    fontSize:
                                                    12),
                                              ),
                                            ],
                                          ),
                                          trailing: const Icon(
                                            Icons
                                                .arrow_forward_ios,
                                            color:
                                            Colors.orange,
                                            size: 16,
                                          ),
                                          onTap: () => Navigator
                                              .pop(
                                              context,
                                              customer
                                                  .toMap()),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                // FOOTER
                Padding(
                  padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                              color: Colors.white70),
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
    );
  }
}