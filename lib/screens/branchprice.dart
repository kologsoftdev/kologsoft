// import 'dart:async';
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../models/itemregmodel.dart';
// import '../providers/Datafeed.dart';
//
// import 'branchpriceedit.dart';
//
// class BranchPricePage extends StatefulWidget {
//   const BranchPricePage({super.key});
//
//   @override
//   State<BranchPricePage> createState() => _BranchPricePageState();
// }
//
// class _BranchPricePageState extends State<BranchPricePage> {
//   final FirebaseFirestore db = FirebaseFirestore.instance;
//   String searchQuery = '';
//   String? userbranchid;
//   String? userrole;
//   String? staff;
//   String? companyid;
//   String? selectedBranchId;
//   String? selectedBranchName;
//   bool showSearch = false;
//   int _rowsPerPage = 10;
//   int? _sortColumnIndex;
//   bool _sortAscending = true;
//   final ScrollController _verticalController = ScrollController();
//   final ScrollController _horizontalController = ScrollController();
//   @override
//   void initState() {
//     super.initState();
//     Future.microtask(() async {
//       if (!mounted) return;
//       context.read<Datafeed>().fetchItems();
//       await context.read<Datafeed>().initUserAndBranches();
//       if (!mounted) return;
//       final vvalue = Provider.of<Datafeed>(context, listen: false);
//       companyid = vvalue.companyid;
//       userbranchid = vvalue.branchid;
//       userrole = vvalue.accesslevel;
//       staff = vvalue.staff;
//     });
//   }
//
//   @override
//   void dispose() {
//     _verticalController.dispose();
//     _horizontalController.dispose();
//     super.dispose();
//   }
//   List<ItemModel> filteredItems(Datafeed value) {
//     final query = searchQuery.toLowerCase();
//
//     if (query.isEmpty) return value.items;
//
//     return value.items.where((item) {
//       final name = (item.name ?? '').toLowerCase();
//       final barcode = (item.barcode ?? '').toLowerCase();
//       final company = (item.company ?? '').toLowerCase();
//       final category = (item.pcategory ?? '').toLowerCase();
//
//       return name.contains(query) || barcode.contains(query) ||
//           company.contains(query) ||  category.contains(query); }).toList();
//   }
//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.sizeOf(context) .width;
//
//     final isDesktop = width > 700;
//     return Consumer<Datafeed>(
//       builder: (BuildContext context, Datafeed value, Widget? child) {
//
//         return Scaffold(
//           backgroundColor: const Color(0xFF101624),
//           appBar: AppBar(title: Text(value.company),
//
//           ),
//           body: Align(
//             alignment: Alignment.topCenter,
//             child: Column(
//               children: [
//
//                 Padding(
//                   padding: const EdgeInsets.all(12),
//                   child: Column(
//
//                     children: [
//                       Text('Tap a branch to view and update item prices.',
//                         style: TextStyle(
//                             color: Colors.white70, fontSize: 18),
//                       ),
//                       SizedBox(height: 5,),
//                       if (value.canSelectBranch)
//                        ListView.builder(
//                          itemCount: value.branches.length,
//                            itemBuilder: (context, index) {
//                              final b = value.branches[index];
//                              return ListTile(
//                                title: Text(b.branchname),
//                                onTap: () {
//                                  setState(() {
//                                    selectedBranchId = b.id;
//                                    selectedBranchName = b.branchname;
//                                  });
//                                },
//                              );
//                            }
//
//                        ),
//
//                         ConstrainedBox(
//                           constraints: BoxConstraints(
//                             maxWidth: isDesktop ? 700 : double.infinity,
//                             maxHeight: 400,
//                           ),
//                           child: LayoutBuilder (
//                             builder: (context, constraints) {
//                               int crossAxisCount = isDesktop ? 4 : 2;
//
//                               return GridView.builder(
//
//                                 itemCount: value.branches.length,
//                                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                                   crossAxisCount: crossAxisCount,
//                                   mainAxisSpacing: 12,
//                                   crossAxisSpacing: 12,
//                                   childAspectRatio: 3.5, // controls height
//                                 ),
//                                 itemBuilder: (context, index) {
//                                   final b = value.branches[index];
//                                   final selected = selectedBranchId == b.id;
//
//                                   return InkWell(
//                                     borderRadius: BorderRadius.circular(10),
//                                     onTap: () {
//                                       setState(() {
//                                         selectedBranchId = b.id;
//                                         selectedBranchName = b.branchname;
//                                       });
//                                     },
//                                     child: AnimatedContainer(
//                                       duration: const Duration(milliseconds: 200),
//                                       decoration: BoxDecoration(
//                                         color: selected
//                                             ? Colors.amber
//                                             : const Color(0xFF22304A),
//                                         borderRadius: BorderRadius.circular(10),
//                                         border: Border.all(
//                                           color: selected
//                                               ? Colors.amber
//                                               : Colors.white10,
//                                         ),
//                                       ),
//                                       padding: const EdgeInsets.symmetric(horizontal: 12),
//                                       alignment: Alignment.center,
//                                       child: Row(
//                                         mainAxisAlignment: MainAxisAlignment.center,
//                                         children: [
//                                           Flexible(
//                                             child: Text(
//                                               b.branchname,
//                                               overflow: TextOverflow.ellipsis,
//                                               style: TextStyle(
//                                                 color: selected
//                                                     ? Colors.black
//                                                     : Colors.white,
//                                                 fontWeight: FontWeight.w600,
//                                               ),
//                                             ),
//                                           ),
//                                           if (selected) ...[
//                                             const SizedBox(width: 6),
//                                             const Icon(Icons.lock,
//                                                 size: 16, color: Colors.black),
//                                           ]
//                                         ],
//                                       ),
//                                     ),
//                                   );
//                                 },
//                               );
//                             },
//                           ),
//                         ),
//
//                       const SizedBox(height: 8),
//                     ],
//                   ),
//                 ),
//
//                 //content
//                 AnimatedContainer(
//                   duration: const Duration(milliseconds: 250),
//                   width: showSearch ? 350 : 48,
//                   height: 48,
//                   decoration: BoxDecoration(
//                     color: const Color(0xFF22304A),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Row(
//                     children: [
//                       if (showSearch)
//                         Expanded(
//                           child: TextFormField(
//                             onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
//                             style: const TextStyle(color: Colors.white),
//                             decoration: InputDecoration(
//                               filled: true,
//                               fillColor: const Color(0xFF22304A),
//                               hintText: 'Search items...',
//                               hintStyle: const TextStyle(color: Colors.white54),
//                               prefixIcon: const Icon(
//                                   Icons.search, color: Colors.white54),
//
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(10),
//                                 borderSide: BorderSide.none,
//                               ),
//                               enabledBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(10),
//                                 borderSide: BorderSide.none,
//                               ),
//                               focusedBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(10),
//                                 borderSide: const BorderSide(color: Colors.amber),
//                               ),
//                             ),
//                           ),
//                         ),
//
//                       IconButton(
//                         icon: Icon(
//                           showSearch ? Icons.close : Icons.search,
//                           color: Colors.white70,
//                         ),
//                         onPressed: () {
//                           setState(() {
//                             showSearch = !showSearch;
//                             if (!showSearch) searchQuery = '';
//                           });
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 5,),
//
//                 Expanded(
//                   child: Builder(builder: (_) {
//                     if (selectedBranchId == null) {
//                       return const Center(
//                         child: Text(
//                           'Tap a branch to view items',
//                           style: TextStyle(color: Colors.white70),
//                         ),
//                       );
//                     }
//
//                     if (value.loading) {
//                       return const Center(child: CircularProgressIndicator());
//                     }
//
//                     if (value.items.isEmpty) {
//                       return const Center(
//                         child: Text(
//                           "No items registered yet",
//                           style: TextStyle(color: Colors.white70),
//                         ),
//                       );
//                     }
//
//
//                     final filtered = filteredItems(value);
//
//                     return isDesktop
//                         ? _desktopTable(filtered)
//                         : _mobileCards(filtered);
//                   }),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//
//     );
//   }
//
//   Widget _mobileCards(List<ItemModel> items) {
//     return ListView.builder(
//       padding: const EdgeInsets.all(12),
//       itemCount: items.length,
//       itemBuilder: (context, i) {
//         try {
//           final item = items[i];
//
//           final branchPrices = item.branchprices;
//           final modes = item.modes;
//
//           final hasBranchPricing = branchPrices != null && branchPrices.isNotEmpty;
//
//           final hasModes =  modes != null && modes is Map && modes.isNotEmpty;
//
//           return Card(
//             color: const Color(0xFF1B263B),
//             margin: const EdgeInsets.only(bottom: 12),
//             child: InkWell(
//               onTap: () {
//                 if (selectedBranchId == null) return;
//
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => Branchitempriceupdate(
//                       item: item,
//                       branchId: selectedBranchId!,
//                       staff: staff!,
//                       branchname: selectedBranchName!,
//                     ),
//                   ),
//                 ).then((_) {
//                   if (mounted) setState(() {});
//                 });
//               },
//               child: Padding(
//                 padding: const EdgeInsets.all(12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     /// HEADER
//                     Row(
//                       children: [
//                         CircleAvatar(
//                           backgroundColor: const Color(0xFF415A77),
//                           child: Text('${i + 1}'),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 item.name,
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               if (item.barcode != null &&
//                                   item.barcode!.isNotEmpty)
//                                 Text(
//                                   'Barcode: ${item.barcode}',
//                                   style: const TextStyle(color: Colors.white70),
//                                 ),
//                             ],
//                           ),
//                         ),
//                         const Icon(Icons.chevron_right,
//                             color: Colors.white54),
//                       ],
//                     ),
//
//                     const SizedBox(height: 12),
//
//                     /// PRICING
//                     if (!hasBranchPricing && !hasModes)
//                       const Text(
//                         'No pricing',
//                         style: TextStyle(color: Colors.white38),
//                       ),
//
//                     if (hasBranchPricing)
//                       ...branchPrices!.entries.map((branchEntry) {
//                         final branch = Map<String, dynamic>.from(
//                             branchEntry.value as Map);
//
//                         final branchName = branch['name'] ?? '';
//                         final pricing =
//                         Map<String, dynamic>.from(branch['pricing'] ?? {});
//
//                         if (pricing.isEmpty) return const SizedBox.shrink();
//
//                         return Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             if (branchName.toString().isNotEmpty)
//                               Padding(
//                                 padding:
//                                 const EdgeInsets.only(bottom: 6),
//                                 child: Text(
//                                   branchName,
//                                   style: const TextStyle(
//                                     color: Colors.white70,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ),
//                             ...pricing.entries.map((e) {
//                               final p =
//                               Map<String, dynamic>.from(e.value);
//                               return _pricingCard(
//                                 name: p['name'] ?? e.key,
//                                 qty: p['qty'] ?? '',
//                                 rp: p['rp'] ?? '',
//                                 wp: p['wp'] ?? '',
//                                 sp: p['sp'] ?? '',
//                               );
//                             }).toList(),
//                           ],
//                         );
//                       }).toList(),
//
//                     /// FALLBACK → MODES
//                     if (!hasBranchPricing && hasModes)
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Padding(
//                             padding: EdgeInsets.only(bottom: 6),
//                             child: Text(
//                               'Default Pricing',
//                               style: TextStyle(
//                                 color: Colors.white70,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                           ...modes.map((e) {
//                             return _pricingCard(
//                               name: e.name,
//                               qty: e.qty,
//                               rp: e.rp,
//                               wp: e.wp,
//                               sp: e.sp,
//                             );
//                           }),
//                         ],
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         } catch (e) {
//           print('Error building item card: $e');
//           return Card(
//             color: const Color(0xFF1B263B),
//             child: const ListTile(
//               leading: Icon(Icons.error, color: Colors.redAccent),
//               title: Text('Error loading item',
//                   style: TextStyle(color: Colors.redAccent)),
//             ),
//           );
//         }
//       },
//     );
//   }
//
//
//   Widget _desktopTable(List<ItemModel> items) {
//    // final verticalController = ScrollController();
//   //  final horizontalController = ScrollController();
//     final source = ItemDataSource(
//       items: List.from(items),
//       context: context,
//       selectedBranchId: selectedBranchId,
//       selectedBranchName: selectedBranchName,
//       staff: staff,
//     );
//
//     return ScrollbarTheme(
//       data: ScrollbarThemeData(
//         thumbColor: MaterialStateProperty.all(
//           const Color(0xFF415A77),
//         ),
//         trackColor: MaterialStateProperty.all(
//           const Color(0xFF22304A),
//         ),
//         trackBorderColor: MaterialStateProperty.all(
//           const Color(0xFF1B263B),
//         ),
//         thickness: MaterialStateProperty.all(10),
//         radius: const Radius.circular(8),
//       ),
//       child: Scrollbar(
//         controller: _verticalController,
//         thumbVisibility: true,
//         trackVisibility: true,
//         child: Scrollbar(
//           controller: _horizontalController,
//           thumbVisibility: true,
//           trackVisibility: true,
//           notificationPredicate: (notif) => notif.depth == 1,
//           child: SingleChildScrollView(
//             controller: _verticalController,
//             scrollDirection: Axis.vertical,
//             child: SingleChildScrollView(
//               controller: _horizontalController,
//               scrollDirection: Axis.horizontal,
//               child: SizedBox(
//                 width: 950,
//                 child: Theme(
//                   data: Theme.of(context).copyWith(
//                     textTheme: Theme.of(context).textTheme.apply(
//
//                     ),
//                   ),
//                   child: DataTableTheme(
//                     data: DataTableThemeData(
//                       columnSpacing: 25,
//                       headingRowColor: MaterialStateProperty.all(const Color(0xFF22304A)),
//                       headingTextStyle: const TextStyle(
//                         color: Colors.white70,
//                         fontWeight: FontWeight.w600,
//                         fontSize: 12,
//                         letterSpacing: 0.5,
//                       ),
//                       dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
//                       dataRowColor: MaterialStateProperty.resolveWith((states) =>
//                       states.contains(MaterialState.selected)
//                           ? Colors.blueAccent.withOpacity(0.08)
//                           : const Color(0xFF1B263B),
//                       ),
//                       dividerThickness: 0,
//                     ),
//                     child: PaginatedDataTable(
//                       header: null,
//                       rowsPerPage: 15,
//                       availableRowsPerPage: const [15, 25, 50, 100],
//                       sortColumnIndex: _sortColumnIndex,
//                       sortAscending: _sortAscending,
//                       headingRowHeight: 44,
//                       dataRowMinHeight: 52,
//                       dataRowMaxHeight: 52,
//                       horizontalMargin: 20,
//                       showCheckboxColumn: false,
//                       columns: [
//                         const DataColumn(label: Text('#')),
//                         DataColumn(
//                           label: const Text('Name'),
//                           onSort: (i, a) => setState(() {
//                             _sortColumnIndex = i;
//                             _sortAscending = a;
//                           }),
//                         ),
//                          DataColumn(label: Text('Barcode'),
//                           onSort: (i, a) => setState(() {
//                             _sortColumnIndex = i;
//                             _sortAscending = a;
//                           }),
//                         ),
//                         DataColumn(
//                           label:  Text('Category'),
//                           onSort: (i, a) => setState(() {
//                             _sortColumnIndex = i;
//                             _sortAscending = a;
//                           }),
//                         ),
//                         const DataColumn(label: Text('Pricing')),
//                         const DataColumn(label: Text('Has Price')),
//                         const DataColumn(label: Text('Actions')),
//                       ],
//                       source: source,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _pricingCard({required String name, required dynamic qty,required dynamic rp,required dynamic wp, required dynamic sp,}) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: const Color(0xFF1F2A3A),
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             name,
//             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 4),
//           Wrap(
//             spacing: 12,
//             runSpacing: 12,
//             alignment: WrapAlignment.start,
//             children: [
//               _priceBox("Quantity", qty),
//               _priceBox("Retail Price", rp),
//               _priceBox("Wholesale Price", wp),
//               _priceBox("Supplier Price", sp),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _priceBox(String label, dynamic value) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//       decoration: BoxDecoration(
//         color: const Color(0xFF22304A),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Column(
//         children: [
//           Text(
//             label,
//             style: const TextStyle(color: Colors.white54, fontSize: 11),
//           ),
//           Text(
//             (value?.toString().isEmpty ?? true) ? "-" : value.toString(),
//             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           ),
//         ],
//       ),
//     );
//   }
//
// }
// class ItemDataSource extends DataTableSource {
//   List<ItemModel> items;
//   final BuildContext context;
//   final String? selectedBranchId;
//   final String? selectedBranchName;
//   final String? staff;
//
//   ItemDataSource({
//     required this.items,
//     required this.context,
//     required this.selectedBranchId,
//     required this.selectedBranchName,
//     required this.staff,
//     int sortColumnIndex = 0,
//     bool sortAscending = true,
//   }) {
//     _sort(sortColumnIndex, sortAscending);
//   }
//
//   void _sort(int columnIndex, bool ascending) {
//     items.sort((a, b) {
//       int result = 0;
//       switch (columnIndex) {
//         case 1: // Name
//           result = a.name.compareTo(b.name);
//           break;
//         case 3: // Category
//           result = (a.pcategory).compareTo(b.pcategory ?? '');
//           break;
//         default:
//           return 0;
//       }
//       return ascending ? result : -result;
//     });
//   }
//
//   @override
//   DataRow? getRow(int index) {
//     if (index >= items.length) return null;
//     final item = items[index];
//
//     try {
//       return DataRow(
//         onSelectChanged: (_) {
//           if (selectedBranchId == null) return;
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => Branchitempriceupdate(
//                 item: item,
//                 branchId: selectedBranchId!,
//                 staff: staff!,
//                 branchname: selectedBranchName!,
//               ),
//             ),
//           );
//         },
//         cells: [
//           DataCell(Text('${index + 1}', style: const TextStyle(color: Colors.white))),
//           DataCell(Text(item.name, style: const TextStyle(color: Colors.white))),
//           DataCell(Text(item.barcode, style: const TextStyle(color: Colors.white70))),
//           DataCell(Text(item.pcategory, style: const TextStyle(color: Colors.white70))),
//
//           // Pricing
//           DataCell(Builder(builder: (_) {
//             final branchPrices = item.branchprices;
//             final modes = item.modes;
//
//             final hasBranchPricing = branchPrices != null && branchPrices.isNotEmpty;
//             final hasModes = modes != null && modes.isNotEmpty;
//
//             if (!hasBranchPricing && !hasModes) {
//               return const Text('No pricing', style: TextStyle(color: Colors.white38));
//             }
//
//             String tooltipText = '';
//
//             if (hasBranchPricing && selectedBranchId != null) {
//               final branchData = branchPrices![selectedBranchId];
//               if (branchData != null && branchData['pricing'] != null) {
//                 final pricingMap = Map<String, dynamic>.from(branchData['pricing']);
//                 tooltipText = pricingMap.entries.map((entry) {
//                   final p = Map<String, dynamic>.from(entry.value);
//                   final name = p['name'] ?? entry.key;
//                   final qty = p['qty'] ?? '';
//                   final rp = p['rp'] ?? '';
//                   final wp = p['wp'] ?? '';
//                   final sp = p['sp'] ?? '';
//                   return '$name: Retail=$rp, Box=$wp, Supplier=$sp, Qty=$qty';
//                 }).join('\n');
//               }
//             }
//
//             if (tooltipText.isEmpty && hasModes) {
//               tooltipText = modes.map((m) {
//                 final name = m.name ?? m.id ?? '';
//                 return '$name: Retail=${m.rp}, Box=${m.wp}, Supplier=${m.sp}, Qty=${m.qty}';
//               }).join('\n');
//             }
//
//             return Tooltip(
//               message: tooltipText,
//               waitDuration: const Duration(milliseconds: 300),
//               showDuration: const Duration(seconds: 5),
//               child: const Text(
//                 'View Pricing',
//                 style: TextStyle(
//                   color: Colors.blueAccent,
//                   decoration: TextDecoration.underline,
//                 ),
//               ),
//             );
//           })),
//
//           // Has Price
//           DataCell(Builder(builder: (_) {
//             final branches = item.branchprices;
//             bool hasPricing = false;
//
//             if (selectedBranchId != null &&
//                 branches != null &&
//                 branches.containsKey(selectedBranchId)) {
//               final branch = Map<String, dynamic>.from(branches[selectedBranchId]);
//               final pricing = branch['pricing'];
//               hasPricing = pricing is Map && pricing.isNotEmpty;
//             }
//
//             return Text(
//               hasPricing ? 'Yes' : 'Default',
//               style: TextStyle(
//                 color: hasPricing ? Colors.greenAccent : Colors.white38,
//                 fontWeight: FontWeight.bold,
//               ),
//             );
//           })),
//
//           // Action
//           // DataCell(IconButton(
//           //   icon: const Icon(Icons.edit, color: Colors.amber),
//           //   onPressed: () {
//           //     if (selectedBranchId == null) return;
//           //     Navigator.push(
//           //       context,
//           //       MaterialPageRoute(
//           //         builder: (_) => Branchitempriceupdate(
//           //           item: item,
//           //           branchId: selectedBranchId!,
//           //           staff: staff!,
//           //           branchname: selectedBranchName!,
//           //         ),
//           //       ),
//           //     ).then((_) {
//           //       if (mounted) setState(() {});
//           //     });
//           //   },
//           // )),
//           // AFTER
//           DataCell(IconButton(
//             icon: const Icon(Icons.edit, color: Colors.amber),
//             onPressed: () {
//               if (selectedBranchId == null) return;
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => Branchitempriceupdate(
//                     item: item,
//                     branchId: selectedBranchId!,
//                     staff: staff!,
//                     branchname: selectedBranchName!,
//                   ),
//                 ),
//               ).then((_) {
//                 notifyListeners();
//               });
//             },
//           )),
//         ],
//       );
//     } catch (e) {
//       print('Error row $index: $e');
//       return null;
//     }
//   }
//
//   @override
//   int get rowCount => items.length;
//
//   @override
//   bool get isRowCountApproximate => false;
//
//   @override
//   int get selectedRowCount => 0;
// }

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/itemregmodel.dart';
import '../providers/Datafeed.dart';

import 'branchpriceedit.dart';

class BranchPricePage extends StatefulWidget {
  const BranchPricePage({super.key});

  @override
  State<BranchPricePage> createState() => _BranchPricePageState();
}

class _BranchPricePageState extends State<BranchPricePage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String searchQuery = '';
  String? userbranchid;
  String? userrole;
  String? staff;
  String? companyid;
  String? selectedBranchId;
  String? selectedBranchName;
  bool showSearch = false;
  int _rowsPerPage = 10;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _branchScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      context.read<Datafeed>().fetchItems();
      await context.read<Datafeed>().initUserAndBranches();
      if (!mounted) return;
      final vvalue = Provider.of<Datafeed>(context, listen: false);
      companyid = vvalue.companyid;
      userbranchid = vvalue.branchid;
      userrole = vvalue.accesslevel;
      staff = vvalue.staff;
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _branchScrollController.dispose();
    super.dispose();
  }


  List<ItemModel> filteredItems(Datafeed value) {
    final query = searchQuery.toLowerCase();

    if (query.isEmpty) return value.items;

    return value.items.where((item) {
      final name = (item.name ?? '').toLowerCase();
      final barcode = (item.barcode ?? '').toLowerCase();
      final company = (item.company ?? '').toLowerCase();
      final category = (item.pcategory ?? '').toLowerCase();

      return name.contains(query) ||
          barcode.contains(query) ||
          company.contains(query) ||
          category.contains(query);
    }).toList();
  }


  List<ItemModel> _sortedItems(List<ItemModel> items) {
    final sorted = List<ItemModel>.from(items);
    if (_sortColumnIndex == null) return sorted;

    sorted.sort((a, b) {
      int result = 0;
      switch (_sortColumnIndex) {
        case 1: // Name
          result = a.name.compareTo(b.name);
          break;
        case 3: // Category
          result = (a.pcategory).compareTo(b.pcategory ?? '');
          break;
        default:
          return 0;
      }
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 700;

    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(title: Text(value.company)),
          body: Align(
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        'Tap a branch to view and update item prices.',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                      const SizedBox(height: 5),
                      if (value.canSelectBranch)
                        _branchSelector(value, isDesktop),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),


                if (selectedBranchId != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    width: isDesktop ? _tableWidth : double.infinity,
                    child: TextFormField(
                      onChanged: (v) =>
                          setState(() => searchQuery = v.toLowerCase()),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF22304A),
                        hintText: 'Search items...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          const BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],

                Expanded(
                  child: Builder(builder: (_) {
                    if (selectedBranchId == null) {
                      return const Center(
                        child: Text('',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    if (value.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (value.items.isEmpty) {
                      return const Center(
                        child: Text(
                          "No items registered yet",
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    final filtered = filteredItems(value);

                    return isDesktop
                        ? _desktopTable(filtered)
                        : _mobileCards(filtered);
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _branchSelector(Datafeed value, bool isDesktop) {
    if (selectedBranchId != null) {
      return InkWell(
        onTap: () {
          setState(() {
            selectedBranchId = null;
            selectedBranchName = null;
            showSearch = false;
            searchQuery = '';
          });
        },
        child: Container(
          width: isDesktop? _tableWidth:double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF22304A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue),
          ),
          child: Wrap(
            children: [
              const Icon(Icons.store, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedBranchName ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    selectedBranchId = null;
                    selectedBranchName = null;
                    showSearch = false;
                    searchQuery = '';
                  });
                },
                icon: const Icon(Icons.swap_horiz, color: Colors.blue, size: 18),
                label: const Text(
                  'Change Branch',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    final chooserMaxHeight =screenHeight * (isDesktop ? 0.82 : 0.7);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isDesktop ? 700 : double.infinity,

        maxHeight: chooserMaxHeight,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {

          const spacing = 8.0;
          final columns = isDesktop ? 5 : 1;
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width - 24;
          final chipWidth =
              (availableWidth - spacing * (columns - 1)) / columns;

          return Scrollbar(
            controller: _branchScrollController,
            thumbVisibility: value.branches.length > columns * 2,
            child: SingleChildScrollView(
              controller: _branchScrollController,
              padding: const EdgeInsets.only(right: 4),
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: value.branches.map((b) {
                  final selected = selectedBranchId == b.id;
                  return SizedBox(
                    width: chipWidth,
                    height: 46,
                    child: Material(
                      color: selected ? Colors.amber : const Color(0xFF22304A),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() {
                            selectedBranchId = b.id;
                            selectedBranchName = b.branchname;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? Colors.amber : Colors.white10,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  b.branchname,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                    selected ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (selected) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.check_circle,
                                    size: 14, color: Colors.black),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mobileCards(List<ItemModel> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        try {
          final item = items[i];

          final branchPrices = item.branchprices;
          final modes = item.modes;

          final hasBranchPricing =
              branchPrices != null && branchPrices.isNotEmpty;

          final hasModes = modes != null && modes is Map && modes.isNotEmpty;

          return Card(
            color: const Color(0xFF1B263B),
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                if (selectedBranchId == null) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Branchitempriceupdate(
                      item: item,
                      branchId: selectedBranchId!,
                      staff: staff!,
                      branchname: selectedBranchName!,
                    ),
                  ),
                ).then((_) {
                  if (mounted) setState(() {});
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// HEADER
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF415A77),
                          child: Text('${i + 1}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.barcode != null &&
                                  item.barcode!.isNotEmpty)
                                Text(
                                  'Barcode: ${item.barcode}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),

                    const SizedBox(height: 12),

                    /// PRICING
                    if (!hasBranchPricing && !hasModes)
                      const Text(
                        'No pricing',
                        style: TextStyle(color: Colors.white38),
                      ),

                    if (hasBranchPricing)
                      ...branchPrices!.entries.map((branchEntry) {
                        final branch =
                        Map<String, dynamic>.from(branchEntry.value as Map);

                        final branchName = branch['name'] ?? '';
                        final pricing =
                        Map<String, dynamic>.from(branch['pricing'] ?? {});

                        if (pricing.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (branchName.toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  branchName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ...pricing.entries.map((e) {
                              final p = Map<String, dynamic>.from(e.value);
                              return _pricingCard(
                                name: p['name'] ?? e.key,
                                qty: p['qty'] ?? '',
                                rp: p['rp'] ?? '',
                                wp: p['wp'] ?? '',
                                sp: p['sp'] ?? '',
                              );
                            }).toList(),
                          ],
                        );
                      }).toList(),

                    /// FALLBACK → MODES
                    if (!hasBranchPricing && hasModes)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Default Pricing',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...modes.map((e) {
                            return _pricingCard(
                              name: e.name,
                              qty: e.qty,
                              rp: e.rp,
                              wp: e.wp,
                              sp: e.sp,
                            );
                          }),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        } catch (e) {
          print('Error building item card: $e');
          return Card(
            color: const Color(0xFF1B263B),
            child: const ListTile(
              leading: Icon(Icons.error, color: Colors.redAccent),
              title: Text('Error loading item',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          );
        }
      },
    );
  }

  static const double _colIndexW = 30;
  static const double _colNameW = 200;
  static const double _colBarcodeW = 200;
  static const double _colCategoryW = 90;
  static const double _colPricingW = 90;
  static const double _colHasPriceW = 90;
  static const double _colActionsW = 90;
  static const double _tableWidth = _colIndexW +
      _colNameW +
      _colBarcodeW +
      _colCategoryW +
      _colPricingW +
      _colHasPriceW +
      _colActionsW +
      (25 * 6) +
      40;

  Widget _headerCell(String label, {double width = 0, int? sortIndex}) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        if (sortIndex != null && _sortColumnIndex == sortIndex)
          Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: Colors.amber,
          ),
      ],
    );

    final cell = SizedBox(
      width: width,
      child: child,
    );

    if (sortIndex == null) return cell;

    return InkWell(
      onTap: () => _onSort(sortIndex),
      child: cell,
    );
  }

  Widget _dataCell(Widget child, double width) {
    return SizedBox(width: width, child: child);
  }

  Widget _desktopTable(List<ItemModel> items) {
    final sorted = _sortedItems(items);

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
        trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
        trackBorderColor: MaterialStateProperty.all(const Color(0xFF1B263B)),
        thickness: MaterialStateProperty.all(10),
        radius: const Radius.circular(8),
      ),
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        notificationPredicate: (notif) => notif.depth == 1,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _tableWidth,
            child: Column(
              children: [
                // Header row
                Container(
                  color: const Color(0xFF22304A),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      _headerCell('#', width: _colIndexW),
                      const SizedBox(width: 25),
                      _headerCell('Name', width: _colNameW, sortIndex: 1),
                      const SizedBox(width: 25),
                      _headerCell('Barcode', width: _colBarcodeW),
                      const SizedBox(width: 25),
                      _headerCell('Category',
                          width: _colCategoryW, sortIndex: 3),
                      const SizedBox(width: 25),
                      _headerCell('Pricing', width: _colPricingW),
                      const SizedBox(width: 25),
                      _headerCell('Has Price', width: _colHasPriceW),
                      const SizedBox(width: 25),
                      _headerCell('Actions', width: _colActionsW),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: Scrollbar(
                   // controller: _verticalController,
                   // thumbVisibility: true,
                  //  trackVisibility: true,
                    child: ListView.builder(
                    //  controller: _verticalController,
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        return _desktopRow(sorted, index);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopRow(List<ItemModel> items, int index) {
    final item = items[index];

    try {
      final branchPrices = item.branchprices;
      final modes = item.modes;

      final hasBranchPricing = branchPrices != null && branchPrices.isNotEmpty;
      final hasModes = modes != null && modes.isNotEmpty;

      String tooltipText = '';

      if (hasBranchPricing && selectedBranchId != null) {
        final branchData = branchPrices![selectedBranchId];
        if (branchData != null && branchData['pricing'] != null) {
          final pricingMap = Map<String, dynamic>.from(branchData['pricing']);
          tooltipText = pricingMap.entries.map((entry) {
            final p = Map<String, dynamic>.from(entry.value);
            final name = p['name'] ?? entry.key;
            final qty = p['qty'] ?? '';
            final rp = p['rp'] ?? '';
            final wp = p['wp'] ?? '';
            final sp = p['sp'] ?? '';
            return '$name: Retail=$rp, Box=$wp, Supplier=$sp, Qty=$qty';
          }).join('\n');
        }
      }

      if (tooltipText.isEmpty && hasModes) {
        tooltipText = modes.map((m) {
          final name = m.name ?? m.id ?? '';
          return '$name: Retail=${m.rp}, Box=${m.wp}, Supplier=${m.sp}, Qty=${m.qty}';
        }).join('\n');
      }

      bool hasPricing = false;
      if (selectedBranchId != null &&
          branchPrices != null &&
          branchPrices.containsKey(selectedBranchId)) {
        final branch = Map<String, dynamic>.from(branchPrices[selectedBranchId]);
        final pricing = branch['pricing'];
        hasPricing = pricing is Map && pricing.isNotEmpty;
      }

      return InkWell(
        onTap: () {
          if (selectedBranchId == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Branchitempriceupdate(
                item: item,
                branchId: selectedBranchId!,
                staff: staff!,
                branchname: selectedBranchName!,
              ),
            ),
          ).then((_) {
            if (mounted) setState(() {});
          });
        },
        child: Container(
          color: const Color(0xFF1B263B),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          margin: const EdgeInsets.only(bottom: 1),
          child: Row(
            children: [
              _dataCell(
                Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                _colIndexW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                Text(item.name, style: const TextStyle(color: Colors.white)),
                _colNameW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                Text(item.barcode, style: const TextStyle(color: Colors.white70)),
                _colBarcodeW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                Text(item.pcategory, style: const TextStyle(color: Colors.white70)),
                _colCategoryW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                (!hasBranchPricing && !hasModes)
                    ? const Text('No pricing',
                    style: TextStyle(color: Colors.white38))
                    : Tooltip(
                  message: tooltipText,
                  waitDuration: const Duration(milliseconds: 300),
                  showDuration: const Duration(seconds: 5),
                  child: const Text(
                    'View Pricing',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                _colPricingW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                Text(
                  hasPricing ? 'Yes' : 'Default',
                  style: TextStyle(
                    color: hasPricing ? Colors.greenAccent : Colors.white38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _colHasPriceW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.amber),
                  onPressed: () {
                    if (selectedBranchId == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Branchitempriceupdate(
                          item: item,
                          branchId: selectedBranchId!,
                          staff: staff!,
                          branchname: selectedBranchName!,
                        ),
                      ),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                ),
                _colActionsW,
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error row $index: $e');
      return Container(
        color: const Color(0xFF1B263B),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: const Text('Error loading row',
            style: TextStyle(color: Colors.redAccent)),
      );
    }
  }

  Widget _pricingCard({
    required String name,
    required dynamic qty,
    required dynamic rp,
    required dynamic wp,
    required dynamic sp,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2A3A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: [
              _priceBox("Quantity", qty),
              _priceBox("Retail Price", rp),
              _priceBox("Wholesale Price", wp),
              _priceBox("Supplier Price", sp),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceBox(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF22304A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          Text(
            (value?.toString().isEmpty ?? true) ? "-" : value.toString(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
