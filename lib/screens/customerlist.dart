import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kologsoft/models/customerreg_model.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import 'customer_registration.dart';

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchCustomers();
    });
  }

  List<CustomerRegModel> _filteredCustomerlist(
      List<CustomerRegModel> customers) {
    if (searchQuery.isEmpty) {
      return List<CustomerRegModel>.from(customers);
    }

    final query = searchQuery.toLowerCase();

    return customers.where((c) {
      return [
        c.name,
        c.creditlimit?.toString(),
        c.paymentduration,
        c.staff,
        c.contact,
      ].any((field) => (field ?? '').toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final datafeed = context.watch<Datafeed>();
    final customers = datafeed.customerlist;

    final filteredCustomers = _filteredCustomerlist(customers);

    final screenWidth = MediaQuery.of(context).size.width;
    final listWidth =
    screenWidth > 900 ? screenWidth * 0.6 : screenWidth * 0.95;

    return Scaffold(
      backgroundColor: const Color(0xFF121927),
      appBar: AppBar(
        title: const Text("Registered Customers"),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF415A77),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CustomerRegistration(),
            ),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                /// SEARCH
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: TextFormField(
                    cursorColor: Colors.white,
                    onChanged: (v) => setState(() => searchQuery = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search customers...',
                      hintStyle: TextStyle(color: Colors.white54),
                      prefixIcon:
                      Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Color(0xFF22304A),
                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                ///
                Expanded(
                  child: customers.isEmpty
                      ? const Center(
                    child: CircularProgressIndicator(),
                  )
                      : filteredCustomers.isEmpty
                      ? const Center(
                    child: Text(
                      'No customers found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer =  filteredCustomers[index];

                      return Container(
                        key: ValueKey(customer.id),
                        margin:   const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B263B),
                          borderRadius:
                          BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),

                            /// DETAILS
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  customer.customertype ==
                                      "Credit"
                                      ? Text(
                                    "Type: ${customer.customertype}\n"
                                        "Credit Limit: ${customer.creditlimit ?? '0'}\n"
                                        "Payment Duration: ${customer.paymentduration ?? ''}\n"
                                        "Contact: ${customer.contact}",
                                    style:
                                    const TextStyle(
                                      color:
                                      Colors.white70,
                                      height: 1.4,
                                    ),
                                  )
                                      : Text(
                                    "Type: ${customer.customertype}\n"
                                        "Contact: ${customer.contact}",
                                    style:
                                    const TextStyle(
                                      color:
                                      Colors.white70,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            ///EDIT
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.amber),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CustomerRegistration(
                                          docId: customer.id,
                                          data: customer,
                                        ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () async {
                                final confirm =
                                await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text(
                                        "Delete customer"),
                                    content: const Text(
                                        "Are you sure you want to delete this customer?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(
                                                context,
                                                false),
                                        child: const Text(
                                          "Cancel",
                                          style: TextStyle(
                                              color:
                                              Colors.red),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          elevation: 2,
                                        ),
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await context.read<Datafeed>().deleteCustomer(customer.id);
                                  setState(() {
                                    filteredCustomers.removeWhere((c)=>c.id ==customer.id);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                       backgroundColor: Colors.green,
                                        content: Text("Customer deleted",style: TextStyle(color: Colors.white),)),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}