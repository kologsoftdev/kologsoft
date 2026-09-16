import 'package:flutter/material.dart';
import 'package:kologsoft/models/sub_account_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class PaymentMethodsListScreen extends StatefulWidget {
  const PaymentMethodsListScreen({Key? key}) : super(key: key);

  @override
  State<PaymentMethodsListScreen> createState() =>
      _PaymentMethodsListScreenState();
}

class _PaymentMethodsListScreenState
    extends State<PaymentMethodsListScreen> {
  Widget _buildShimmerLoader() {
    return ListView.builder(
      itemCount: 4,
      itemBuilder: (context, index) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              width: 800,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Shimmer.fromColors(
                baseColor: const Color(0xFF182232),
                highlightColor: const Color(0xFF223041),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  final List<String> paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Cheque',
    'MOMO',
  ];

  final List<IconData> iconData = [
    Icons.payments_outlined,
    Icons.account_balance_outlined,
    Icons.receipt_long_outlined,
    Icons.phone_android_outlined,
  ];

  List<SubAccountModel> assetAccounts = [];
  Map<String, List<String>> selectedAssetsPerMethod = {};

  bool selectionsLoaded = false;

  bool isLoading = true;
  String? error;

  String? expandedMethod; // Only one open at a time

  @override
  void initState() {
    super.initState();
    fetchAccounts();
  }

  Future<void> fetchAccounts() async {
    try {
      final datafeed = context.read<Datafeed>();
      final snapshot = await datafeed.db.collection('accounts').get();
      assetAccounts = snapshot.docs.map((doc) => SubAccountModel.fromJson(doc.data())).toList();

      // Restore selections from Firestore
      final companyId = datafeed.companyid;
      for (final method in paymentMethods) {
        final docId = '${companyId}_$method'.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
        final doc = await datafeed.db.collection('paymentaccounts').doc(docId).get();
        if (doc.exists) {
          final data = doc.data();
          final linkedNames = List<String>.from(data?['linkedAccounts'] ?? []);
          // Map names to IDs
          final selectedIds = assetAccounts
              .where((a) => linkedNames.contains(a.name))
              .map((a) => a.id)
              .toList();
          selectedAssetsPerMethod[method] = selectedIds;
        } else {
          selectedAssetsPerMethod[method] = [];
        }
      }
      selectionsLoaded = true;
    } catch (e) {
      error = e.toString();
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101A23),
      appBar: AppBar(
        title: const Text('Payment Methods'),
        backgroundColor: const Color(0xFF0D1A26),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? _buildShimmerLoader()
          : ListView.builder(
        itemCount: paymentMethods.length,
        itemBuilder: (context, index) {
          final method = paymentMethods[index];
          final icon = iconData[index];

          if (!selectionsLoaded) selectedAssetsPerMethod.putIfAbsent(method, () => []);

          final isExpanded = expandedMethod == method;
          final selectedCount = selectedAssetsPerMethod[method]!.length;

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: 800,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF182232),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [

                    // HEADER
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            expandedMethod = null;
                          } else {
                            expandedMethod = method;
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [

                            // ICON
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.15),
                                borderRadius:
                                BorderRadius.circular(30),
                              ),
                              child: Icon(
                                icon,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // METHOD NAME
                            Expanded(
                              child: Text(
                                method,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            // BADGE
                            if (selectedCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius:
                                  BorderRadius.circular(20),
                                ),
                                child: Text(
                                  selectedCount.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12),
                                ),
                              ),

                            const SizedBox(width: 8),

                            // ANIMATED ARROW
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration:
                              const Duration(milliseconds: 300),
                              child: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // EXPANDABLE CONTENT
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Column(
                        children: [

                          ...assetAccounts.map((account) {
                            return CheckboxListTile(
                              title: Text(
                                account.name,
                                style: const TextStyle(
                                    color: Colors.white),
                              ),
                              value:
                              selectedAssetsPerMethod[method]!
                                  .contains(account.id),
                              activeColor: Colors.blue,
                              side: const BorderSide(
                                  color: Colors.white54),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    selectedAssetsPerMethod[method]!
                                        .add(account.id);
                                  } else {
                                    selectedAssetsPerMethod[method]!.remove(account.id);
                                  }
                                });
                              },
                            );

                          }).toList(),

                          // SAVE BUTTON
                          Padding(
                            padding:
                            const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: double.infinity,
                              height: 35,
                              child: ElevatedButton(
                                style:
                                ElevatedButton.styleFrom(
                                  backgroundColor:
                                  Colors.blue,
                                  shape:
                                  RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(20),
                                  ),
                                ),
                                onPressed: () async {
                                  try {
                                    final datafeed = context.read<Datafeed>();
                                    final companyId = datafeed.companyid;
                                    final staff = datafeed.staff;
                                    final docId = '${companyId}_$method'.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
                                    // Map selected asset IDs to their names
                                    final selectedNames = assetAccounts
                                        .where((a) => selectedAssetsPerMethod[method]!.contains(a.id))
                                        .map((a) => a.name)
                                        .toList();
                                    await datafeed.db.collection('paymentaccounts').doc(docId).set({
                                      'paymentMethod': method,
                                      'companyId': companyId,
                                      'linkedAccounts': selectedNames,
                                      'updatedAt': DateTime.now().toIso8601String(),
                                      'staff': staff,
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Saved $selectedCount assets to $method'),
                                      ),
                                    );
                                    setState(() {
                                      expandedMethod = null;
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error saving: ' + e.toString()),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Save Links', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}