//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
//
// import '../providers/Datafeed.dart';
// import 'bundlesale.dart';
//
//
// class bundleSaleViewPage extends StatefulWidget {
//   const bundleSaleViewPage({super.key});
//
//   @override
//   State<bundleSaleViewPage> createState() => _bundleSaleViewPageState();
// }
//
// class _bundleSaleViewPageState extends State<bundleSaleViewPage> {
//   String searchQuery = '';
//   DateTimeRange? selectedDate;
//   String _selectedBranch = '';
//   String? _selectedBranchName;
//   int? _sortColumnIndex;
//   bool _sortAscending = true;
//   int _rowsPerPage = 10;
//   final verticalController = ScrollController();
//   final horizontalController = ScrollController();
//
//   void _sort<T>(
//       Comparable<T> Function(dynamic d) getField,
//       int columnIndex,
//       bool ascending,
//       List list,
//       ) {
//     list.sort((a, b) {
//       final aValue = getField(a);
//       final bValue = getField(b);
//
//       return ascending
//           ? Comparable.compare(aValue, bValue)
//           : Comparable.compare(bValue, aValue);
//     });
//     setState(() {
//       _sortColumnIndex = columnIndex;
//       _sortAscending = ascending;
//     });
//   }
//   Future<void> pickDateRange(BuildContext context) async {
//     final DateTimeRange? picked = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2100),
//       initialDateRange: selectedDate,
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             textButtonTheme: TextButtonThemeData(
//               style: TextButton.styleFrom(foregroundColor: Colors.white),
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );
//
//     if (picked != null) {
//       setState(() {
//         selectedDate = picked;
//       });
//
//       if (_selectedBranch.isEmpty) {
//         context.read<Datafeed>().fetchbundlesales();
//       } else {
//         context.read<Datafeed>().fetchbundlesales(selectedBranch: _selectedBranch);
//       }
//     }
//   }
//   String capitalize(String? text) {
//     if (text == null || text.isEmpty) return '';
//     return text[0].toUpperCase() + text.substring(1);
//   }
//
//   Map<String, dynamic> _itemMapOf(dynamic salesview) {
//     final rawItems = salesview['items'];
//     if (rawItems is Map) {
//       return Map<String, dynamic>.from(rawItems);
//     } else if (rawItems is List) {
//       return {
//         for (int i = 0; i < rawItems.length; i++) i.toString(): rawItems[i]
//       };
//     }
//     return {};
//   }
//
//   double _totalOf(Map<String, dynamic> itemMap) {
//     return itemMap.values.fold<double>(0, (sum, item) {
//       if (item is Map<String, dynamic>) {
//         final amount = double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0;
//         return sum + amount;
//       }
//       return sum;
//     });
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     Future.microtask((){
//       context.read<Datafeed>().fetchBranches();
//       context.read<Datafeed>().fetchbundlesales();
//     });
//
//   }
//   @override
//   Widget build(BuildContext context) {
//     final ScreenWidth = MediaQuery.sizeOf(context).width;
//     return Consumer<Datafeed>(
//       builder: (context, value, child) {
//         final filteredSalesview = value.filterbundlesales();
//
//         return Scaffold(
//           backgroundColor: const Color(0xFF101624),
//           appBar: AppBar(
//             title: const Text('Bundle Sales View List'),
//             actions: [
//
//             ],
//           ),
//
//           floatingActionButton: FloatingActionButton(
//             backgroundColor: const Color(0xFF415A77),
//             child: const Icon(Icons.add),
//             onPressed: () {
//               Navigator.push(context, MaterialPageRoute(builder: (_) =>  BundlePage()),
//               );
//             },
//           ),
//           body: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Align(
//               alignment: Alignment.topCenter,
//               child: ConstrainedBox(
//                 constraints: const BoxConstraints(maxWidth: 900),
//                 child: Column(
//                   children: [
//                     DropdownButtonFormField<String?>(
//                       value: (() {
//                         final id = value.selectedBranch?.id;
//                         if (id == null) return null;
//                         final exists = value.branches.any((b) => b.id == id);
//                         return exists ? id : null;
//                       })(),
//                       isExpanded: true,
//                       dropdownColor: const Color(0xFF22304A),
//                       style: const TextStyle(color: Colors.white),
//                       decoration: InputDecoration(
//                         labelText: 'Select Branch',
//                         labelStyle: const TextStyle(color: Colors.white70),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: const BorderSide(color: Colors.white24),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: const BorderSide(color: Colors.blue),
//                         ),
//                         fillColor: const Color(0xFF22304A),
//                         filled: true,
//                       ),
//                       items: [
//                         const DropdownMenuItem<String?>(
//                           value: null,
//                           child: Text('All Branches', style: TextStyle(color: Colors.white)),
//                         ),
//                         ...{ for (var b in value.branches) b.id: b }
//                             .values
//                             .map((branch) => DropdownMenuItem<String?>(
//                           value: branch.id,
//                           child: Text(
//                             branch.branchname,
//                             style: const TextStyle(color: Colors.white),
//                           ),
//                         )),
//                       ],
//                       onChanged: (val) {
//                         setState(() {
//                           _selectedBranch = val ?? '';
//                           _selectedBranchName = val == null
//                               ? ''
//                               : value.branches
//                               .firstWhere((b) => b.id == val)
//                               .branchname;
//                         });
//
//                         if (val == null) {
//                           value.fetchbundlesales();
//                         } else {
//                           value.fetchbundlesales(selectedBranch: val);
//                         }
//                       },
//                     ),
//                     const SizedBox(height: 10),
//                     TextFormField(
//                       cursorColor: Colors.white70,
//                       onChanged: value.updateSearch,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: const InputDecoration(
//                         hintText: 'Search ...',
//                         hintStyle: TextStyle(color: Colors.white54),
//                         prefixIcon: Icon(Icons.search, color: Colors.white54),
//                         filled: true,
//                         fillColor: Color(0xFF22304A),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.all(Radius.circular(8)),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     if ((_selectedBranchName ?? '').isNotEmpty) ...[
//                       Text(
//                         'Bundle View for $_selectedBranchName',
//                         style: const TextStyle(fontSize: 12, color: Colors.white),
//                       ),
//                     ] else if (_selectedBranch.isEmpty && value.bundleview.isNotEmpty) ...[
//                       Text(
//                         'Bundle View for All Branches',
//                         style: const TextStyle(fontSize: 12, color: Colors.white),
//                       ),
//                     ],
//
//                     Expanded(
//                       child: value.isloadingsalesbundle
//                           ? const Center(
//                         child: CircularProgressIndicator(color: Colors.white),
//                       )
//                           : value.bundleview.isEmpty
//                           ? const Center(
//                         child: Text(
//                           'No Sales found',
//                           style: TextStyle(color: Colors.white70),
//                         ),
//                       )
//                           : LayoutBuilder(
//                         builder: (context, constraints) {
//                           final isDesktop = ScreenWidth>900;
//
//                           if (isDesktop) {
//                             // Apply current sort before building rows
//                             if (_sortColumnIndex != null) {
//                               switch (_sortColumnIndex) {
//                                 case 1:
//                                   filteredSalesview.sort((a, b) {
//                                     final cmp = (a['name'] ?? '').toString().toLowerCase()
//                                         .compareTo((b['name'] ?? '').toString().toLowerCase());
//                                     return _sortAscending ? cmp : -cmp;
//                                   });
//                                   break;
//                                 case 2:
//                                   filteredSalesview.sort((a, b) {
//                                     final aFirst = _itemMapOf(a).values.isNotEmpty &&
//                                         _itemMapOf(a).values.first is Map<String, dynamic>
//                                         ? (_itemMapOf(a).values.first as Map<String, dynamic>)['item']?.toString().toLowerCase() ?? ''
//                                         : '';
//                                     final bFirst = _itemMapOf(b).values.isNotEmpty &&
//                                         _itemMapOf(b).values.first is Map<String, dynamic>
//                                         ? (_itemMapOf(b).values.first as Map<String, dynamic>)['item']?.toString().toLowerCase() ?? ''
//                                         : '';
//                                     final cmp = aFirst.compareTo(bFirst);
//                                     return _sortAscending ? cmp : -cmp;
//                                   });
//                                   break;
//                                 case 3:
//                                   filteredSalesview.sort((a, b) {
//                                     final ta = _totalOf(_itemMapOf(a));
//                                     final tb = _totalOf(_itemMapOf(b));
//                                     final cmp = ta.compareTo(tb);
//                                     return _sortAscending ? cmp : -cmp;
//                                   });
//                                   break;
//                                 case 4:
//                                   filteredSalesview.sort((a, b) {
//                                     final da = (a['createdat'] as Timestamp?)?.toDate() ?? DateTime(1900);
//                                     final db = (b['createdat'] as Timestamp?)?.toDate() ?? DateTime(1900);
//                                     final cmp = da.compareTo(db);
//                                     return _sortAscending ? cmp : -cmp;
//                                   });
//                                   break;
//                               }
//                             }
//
//                             const columnWidths = <double>[40, 150, 220, 110, 130, 120, 200];
//                             const columnLabels = <String>[
//                               '#', 'Name', 'Item', 'Total', 'Date', 'Enable/Disable', 'Action'
//                             ];
//
//                             Widget buildHeaderLabel(int index) {
//                               final sortable = index == 1 || index == 2 || index == 3 || index == 4;
//                               final isActive = _sortColumnIndex == index;
//                               final label = Text(
//                                 columnLabels[index],
//                                 style: const TextStyle(
//                                   color: Colors.white70,
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: 12,
//                                   letterSpacing: 0.5,
//                                 ),
//                               );
//
//                               Widget content = label;
//                               if (sortable) {
//                                 content = Row(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     label,
//                                     if (isActive) ...[
//                                       const SizedBox(width: 4),
//                                       Icon(
//                                         _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
//                                         color: Colors.white70,
//                                         size: 14,
//                                       ),
//                                     ],
//                                   ],
//                                 );
//                               }
//
//                               return SizedBox(
//                                 width: columnWidths[index],
//                                 child: sortable
//                                     ? InkWell(
//                                   onTap: () => setState(() {
//                                     if (_sortColumnIndex == index) {
//                                       _sortAscending = !_sortAscending;
//                                     } else {
//                                       _sortColumnIndex = index;
//                                       _sortAscending = true;
//                                     }
//                                   }),
//                                   child: Align(alignment: Alignment.centerLeft, child: content),
//                                 )
//                                     : Align(alignment: Alignment.centerLeft, child: content),
//                               );
//                             }
//
//                             List<Widget> withSpacing(List<Widget> cells) {
//                               final spaced = <Widget>[];
//                               for (var i = 0; i < cells.length; i++) {
//                                 spaced.add(cells[i]);
//                                 if (i != cells.length - 1) spaced.add(const SizedBox(width: 10));
//                               }
//                               return spaced;
//                             }
//
//                             return ScrollbarTheme(
//                               data: ScrollbarThemeData(
//                                 thumbColor: MaterialStateProperty.all(
//                                   const Color(0xFF415A77),
//                                 ),
//                                 trackColor: MaterialStateProperty.all(
//                                   const Color(0xFF22304A),
//                                 ),
//                                 trackBorderColor: MaterialStateProperty.all(
//                                   const Color(0xFF1B263B),
//                                 ),
//                                 thickness: MaterialStateProperty.all(10),
//                                 radius: const Radius.circular(8),
//                               ),
//                               child: Scrollbar(
//                                 controller: verticalController,
//                                 thumbVisibility: true,
//                                 trackVisibility: true,
//                                 child: Scrollbar(
//                                   controller: horizontalController,
//                                   thumbVisibility: true,
//                                   trackVisibility: true,
//                                   notificationPredicate: (notif) => notif.depth == 1,
//                                   child: SingleChildScrollView(
//                                     controller: horizontalController,
//                                     scrollDirection: Axis.horizontal,
//                                     child: SizedBox(
//                                       width: columnWidths.fold<double>(0, (a, b) => a + b) +
//                                           (columnWidths.length - 1) * 10,
//                                       child: Column(
//                                         children: [
//                                           Container(
//                                             height: 44,
//                                             padding: const EdgeInsets.symmetric(horizontal: 15),
//                                             color: const Color(0xFF22304A),
//                                             child: Row(
//                                               children: withSpacing(
//                                                 List.generate(columnLabels.length, buildHeaderLabel),
//                                               ),
//                                             ),
//                                           ),
//                                           Expanded(
//                                             child: ListView.builder(
//                                               controller: verticalController,
//                                               itemCount: filteredSalesview.length,
//                                               itemBuilder: (context, index) {
//                                                 final salesview = filteredSalesview[index];
//                                                 final id = salesview['id'] ?? '';
//                                                 final name = salesview['name'] ?? '';
//                                                 final itemMap = _itemMapOf(salesview);
//
//                                                 final firstItem = itemMap.values.isNotEmpty &&
//                                                     itemMap.values.first is Map<String, dynamic>
//                                                     ? itemMap.values.first as Map<String, dynamic>
//                                                     : {};
//                                                 final itemName = firstItem['item']?.toString() ?? name;
//
//                                                 final itemsSummary = itemMap.values
//                                                     .whereType<Map<String, dynamic>>()
//                                                     .map((e) => "${e['item']}(${e['quantity']})")
//                                                     .join(", ");
//
//                                                 final total = _totalOf(itemMap);
//
//                                                 final dateStr = salesview['createdat'] != null
//                                                     ? (salesview['createdat'] as Timestamp)
//                                                     .toDate()
//                                                     .toString()
//                                                     .split(' ')
//                                                     .first
//                                                     : '';
//
//                                                 final cells = <Widget>[
//                                                   Text('${index + 1}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
//                                                   Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
//                                                   Text(
//                                                     itemsSummary,
//                                                     style: const TextStyle(color: Colors.white, fontSize: 12),
//                                                     maxLines: 2,
//                                                     overflow: TextOverflow.ellipsis,
//                                                   ),
//                                                   Text(
//                                                     NumberFormat("#,##0.00").format(total),
//                                                     style: const TextStyle(color: Colors.white, fontSize: 12),
//                                                   ),
//                                                   Text(dateStr, style: const TextStyle(color: Colors.white, fontSize: 12)),
//                                                   Switch(
//                                                     value: salesview['isActive'] == true,
//                                                     activeColor: Colors.green,
//                                                     onChanged: (val) {
//                                                       context.read<Datafeed>().toggleItemActive(
//                                                         docId: id,
//                                                         newStatus: val,
//                                                       );
//                                                     },
//                                                   ),
//                                                   Row(
//                                                     children: [
//                                                       IconButton(
//                                                         icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
//                                                         onPressed: () {
//                                                           final itemList = itemMap.values
//                                                               .whereType<Map<String, dynamic>>()
//                                                               .toList();
//                                                           _handleEdit(context, id, itemList);
//                                                         },
//                                                       ),
//                                                       IconButton(
//                                                         icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
//                                                         onPressed: () => _handleDelete(context, itemName, id),
//                                                       ),
//                                                     ],
//                                                   ),
//                                                 ];
//
//                                                 return Container(
//                                                   constraints: const BoxConstraints(minHeight: 52),
//                                                   padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
//                                                   color: index.isEven
//                                                       ? const Color(0xFF0D1B2A)
//                                                       : const Color(0xFF10192B),
//                                                   child: Row(
//                                                     crossAxisAlignment: CrossAxisAlignment.center,
//                                                     children: withSpacing(
//                                                       List.generate(columnWidths.length, (i) {
//                                                         return SizedBox(
//                                                           width: columnWidths[i],
//                                                           child: Align(alignment: Alignment.centerLeft, child: cells[i]),
//                                                         );
//                                                       }),
//                                                     ),
//                                                   ),
//                                                 );
//                                               },
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             );
//                           }
//
//                           /// MOBILE
//                           return ListView.separated(
//                             itemCount: filteredSalesview.length,
//                             separatorBuilder: (_, _) =>
//                             const SizedBox(height: 12),
//                             itemBuilder: (context, index) {
//                               final salesview = filteredSalesview[index];
//
//                               final id = salesview['id'] ?? '';
//                               final name = salesview['name'] ?? '';
//                               final rawItems = salesview['items'];
//                               final bool isActive = salesview['isActive'] == true;
//                               Map<String, dynamic> itemMap = {};
//
//                               if (rawItems is Map) {
//                                 itemMap = Map<String, dynamic>.from(rawItems);
//                               } else if (rawItems is List) {
//                                 itemMap = {
//                                   for (int i = 0; i < rawItems.length; i++) i.toString(): rawItems[i]
//                                 };
//                               }
//
//                               final firstItem = itemMap.values.isNotEmpty &&
//                                   itemMap.values.first is Map<String, dynamic>
//                                   ? itemMap.values.first as Map<String, dynamic> : {};
//
//                               final itemName = firstItem['item']?.toString() ?? '';
//
//                               final totalamountt = itemMap.values.fold<double>( 0, (sum, item) {
//                                 if (item is Map<String, dynamic>) {
//                                   final amount = double.tryParse(
//                                       item['totalamount']?.toString() ?? '0') ?? 0;
//                                   return sum + amount;
//                                 }
//                                 return sum;
//                               },);
//                               return Container(
//                                 margin: const EdgeInsets.symmetric(
//                                     vertical: 8, horizontal: 4),
//                                 decoration: BoxDecoration(
//                                   color: const Color(0xFF1B263B),
//                                   borderRadius: BorderRadius.circular(20),
//                                   border: Border.all( color: Colors.white.withOpacity(0.05)),
//                                   boxShadow: [
//                                     BoxShadow(
//                                       color: Colors.black.withOpacity(0.2),
//                                       blurRadius: 12,
//                                       offset: const Offset(0, 6),
//                                     ),
//                                   ],
//                                 ),
//                                 child: ClipRRect(
//                                   borderRadius: BorderRadius.circular(20),
//                                   child: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       Container(
//                                         padding: const EdgeInsets.all(16),
//                                         color: Colors.white.withOpacity(0.03),
//                                         child: Wrap(
//                                           children: [
//                                             Container(
//                                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                                               decoration: BoxDecoration(
//                                                 color: Colors.amberAccent.withOpacity(0.1),
//                                                 borderRadius: BorderRadius.circular( 8),),
//                                               child: Text(
//                                                 "Name #$name",
//                                                 style: const TextStyle(
//                                                   color: Colors.amberAccent,
//                                                   fontSize: 14,
//                                                   fontWeight: FontWeight.bold,
//                                                   letterSpacing: 1.1,
//                                                 ),
//                                               ),
//                                             ),
//                                             const Spacer(),
//                                             Text("#: ${index + 1}",
//                                               style: TextStyle(
//                                                   color: Colors.white.withOpacity( 0.5),
//                                                   fontSize: 12),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//
//                                       Padding(
//                                         padding: const EdgeInsets.all(16),
//                                         child: Column(
//                                           crossAxisAlignment: CrossAxisAlignment.start,
//                                           children: [
//
//                                             ...itemMap.values.map((item) {
//                                               if (item is! Map<String, dynamic>)
//                                                 return const SizedBox();
//                                               return Container(
//                                                 margin: const EdgeInsets.only( bottom: 16),
//                                                 padding: const EdgeInsets.all(12),
//                                                 decoration: BoxDecoration(
//                                                   color: Colors.black12,
//                                                   borderRadius: BorderRadius.circular(12),
//                                                 ),
//                                                 child: Column(
//                                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                                   children: [
//                                                     Row(
//                                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                                       children: [
//                                                         Expanded(
//                                                           child: Text(
//                                                             item['item']
//                                                                 ?.toUpperCase() ??'',
//                                                             style: const TextStyle(
//                                                               color: Colors.white,
//                                                               fontWeight: FontWeight.w800,
//                                                               fontSize: 14,
//                                                             ),
//                                                           ),
//                                                         ),
//                                                         Text(
//                                                           " ${item['totalamount']}",
//                                                           style: const TextStyle(
//                                                             color: Colors.white70,
//                                                             fontWeight: FontWeight.bold,
//                                                             fontSize: 16,
//                                                           ),
//                                                         ),
//
//
//                                                       ],
//                                                     ),
//                                                     const Divider(color: Colors
//                                                         .white10, height: 20),
//
//                                                     Table(
//                                                       columnWidths: const {
//                                                         0: FlexColumnWidth(1),
//                                                         1: FlexColumnWidth(1),
//                                                       },
//                                                       children: [
//                                                         _buildTableRow("Qty", "${item['quantity']} (${item['mode']})"),
//                                                         _buildTableRow("Price", "GHC ${item['price']}"),
//
//                                                         _buildTableRow("pricemode", " ${capitalize(item['pricemode'])}"),
//                                                         if(item['cp'] != null)
//                                                           _buildTableRow( "Cost Price ","GHC ${item['cp']}"),
//                                                         if(item['barcode'] != null)
//                                                           _buildTableRow("Barcode", "${item['barcode']}"),
//
//
//                                                       ],
//                                                     ),
//
//
//                                                   ],
//                                                 ),
//                                               );
//                                             }),
//
//                                             const Divider(color: Colors.white24),
//
//
//                                             Row(
//                                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                               children: [
//                                                 Column(
//                                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                                   children: [
//                                                     _buildFooterLabel(
//                                                         Icons.person_outline,
//                                                         "Staff: ${salesview['staff']}"),
//                                                     const SizedBox(height: 4),
//                                                     _buildFooterLabel(
//                                                       Icons.calendar_today_outlined,
//                                                       "Date: ${(salesview['createdat'] as Timestamp?)?.toDate()}",
//                                                     ),
//                                                   ],
//                                                 ),
//                                                 Column(
//                                                   crossAxisAlignment: CrossAxisAlignment.end,
//                                                   children: [
//                                                     const Text("TOTAL AMOUNT",
//                                                         style: TextStyle(
//                                                             color: Colors.white54,
//                                                             fontSize: 10)),
//                                                     Text(
//                                                       "GHC ${totalamountt.toString()}",
//                                                       style: const TextStyle(
//                                                         color: Colors.white,
//                                                         fontSize: 20,
//                                                         fontWeight: FontWeight.w900,
//                                                       ),
//                                                     ),
//                                                   ],
//                                                 ),
//                                               ],
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//
//
//                                       Container(
//                                         color: Colors.black26,
//                                         padding: const EdgeInsets.symmetric(
//                                             horizontal: 8),
//                                         child: Row(
//                                           mainAxisAlignment: MainAxisAlignment.spaceAround,
//                                           children: [
//
//                                             _buildActionButton(
//                                               Icons.edit, "Edit",
//                                               Colors.blueAccent,
//                                                   () {
//                                                 List<Map<String, dynamic>> itemList =
//                                                 itemMap.values.whereType<Map<String, dynamic>>().toList();
//
//                                                 _handleEdit(context, id, itemList);
//                                               },
//                                             ),
//                                             _buildActionButton(
//                                               Icons.delete_outline, "Delete",
//                                               Colors.redAccent, () =>
//                                                 _handleDelete(context, itemName, id),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       SwitchListTile(
//                                         title: const Text(
//                                           "Active",
//                                           style: TextStyle(color: Colors.white70),
//                                         ),
//                                         value: salesview['isActive'] == true,
//                                         activeColor: Colors.green,
//
//                                         onChanged: (val) {
//                                           context.read<Datafeed>().toggleItemActive(
//                                             docId: id,
//                                             newStatus: val,
//                                           );
//                                         },
//                                       )
//                                     ],
//                                   ),
//                                 ),
//                               );
//
//                             },
//
//                           );
//                         },
//                       ),
//                     )
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//
//   }
//   TableRow _buildTableRow(String label, String value) {
//     return TableRow(
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 2),
//           child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
//         ),
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 2),
//           child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildFooterLabel(IconData icon, String text) {
//     return Row(
//       children: [
//         Icon(icon, color: Colors.white38, size: 14),
//         const SizedBox(width: 4),
//         Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
//       ],
//     );
//   }
//
//   Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
//     return TextButton.icon(
//       onPressed: onTap,
//       icon: Icon(icon, color: color, size: 20),
//       label: Text(label, style: TextStyle(color: color, fontSize: 13)),
//     );
//   }
//   Future<void> _handleDelete(BuildContext context, String id,String itemName, ) async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (innerContext) => AlertDialog(
//         backgroundColor: const Color(0xFF1B263B),
//         title: Text(
//             "Delete $itemName?",
//             style: const TextStyle(color: Colors.white)
//         ),
//         content: Text(
//           "This action cannot be undone. Are you sure?",
//           style: TextStyle(color: Colors.white.withOpacity(0.7)),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(innerContext, false),
//             child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
//             onPressed: () => Navigator.pop(innerContext, true),
//             child: const Text("Delete", style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//
//     if (confirm == true) {
//       try {
//
//         await context.read<Datafeed>().deletebundleview(id);
//
//         if (context.mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text("$itemName deleted successfully"),
//               backgroundColor: Colors.green,
//               behavior: SnackBarBehavior.floating,
//             ),
//           );
//         }
//       } catch (e) {
//         if (context.mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Failed to delete item"),
//               backgroundColor: Colors.redAccent,
//               behavior: SnackBarBehavior.floating,
//             ),
//           );
//         }
//       }
//     }
//   }
//   Future<void> _handleEdit( BuildContext context, String id, List<Map<String, dynamic>> item, ) async {
//     Navigator.push( context,
//       MaterialPageRoute(
//         builder: (context) => BundlePage(
//           docId: id,
//           item: item,
//         ),
//       ),
//     );
//   }
//
// }


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import 'bundlesale.dart';

class bundleSaleViewPage extends StatefulWidget {
  const bundleSaleViewPage({super.key});

  @override
  State<bundleSaleViewPage> createState() => _bundleSaleViewPageState();
}

class _bundleSaleViewPageState extends State<bundleSaleViewPage> {
  String searchQuery = '';
  DateTimeRange? selectedDate;

  String _selectedBranch = '';
  String? _selectedBranchName;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;

      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchbundlesales();
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

// ---------------------------------------------------------------------------
// DATE FILTER
// ---------------------------------------------------------------------------

  void _clearDateRange() {
    setState(() {
      selectedDate = null;
    });
  }

  List<Map<String, dynamic>> _filterByDateRange(
      List<Map<String, dynamic>> list,
      ) {
    if (selectedDate == null) {
      return list;
    }

    final start = DateTime(
      selectedDate!.start.year,
      selectedDate!.start.month,
      selectedDate!.start.day,
    );

    final end = DateTime(
      selectedDate!.end.year,
      selectedDate!.end.month,
      selectedDate!.end.day,
      23,
      59,
      59,
      999,
    );

    return list.where((sale) {
      final createdAt = sale['createdat'];

      if (createdAt is! Timestamp) {
        return false;
      }

      final date = createdAt.toDate();

      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------

  String capitalize(String? text) {
    if (text == null || text.isEmpty) {
      return '';
    }

    return text[0].toUpperCase() + text.substring(1);
  }

  Map<String, dynamic> _itemMapOf(dynamic salesView) {
    final rawItems = salesView['items'];

    if (rawItems is Map) {
      return Map<String, dynamic>.from(rawItems);
    }

    if (rawItems is List) {
      return {
        for (int i = 0; i < rawItems.length; i++)
          i.toString(): rawItems[i],
      };
    }

    return {};
  }

  double _totalOf(Map<String, dynamic> itemMap) {
    return itemMap.values.fold<double>(
      0,
          (sum, item) {
        if (item is Map) {
          final amount =
              double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0;

          return sum + amount;
        }

        return sum;
      },
    );
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(dynamic value) {
    final date = _timestampToDate(value);

    if (date == null) {
      return '';
    }

    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatDateTime(dynamic value) {
    final date = _timestampToDate(value);

    if (date == null) {
      return '';
    }

    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

// ---------------------------------------------------------------------------
// SORT
// ---------------------------------------------------------------------------

  void _sortSales(
      List<Map<String, dynamic>> list,
      int columnIndex,
      ) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });

    list.sort((a, b) {
      int result = 0;

      switch (columnIndex) {
// Name
        case 1:
          final aName = (a['name'] ?? '').toString().toLowerCase();
          final bName = (b['name'] ?? '').toString().toLowerCase();

          result = aName.compareTo(bName);
          break;

// Item
        case 2:
          final aItems = _itemMapOf(a);
          final bItems = _itemMapOf(b);

          final aFirst = aItems.values.isNotEmpty &&
              aItems.values.first is Map
              ? (aItems.values.first['item'] ?? '')
              .toString()
              .toLowerCase()
              : '';

          final bFirst = bItems.values.isNotEmpty &&
              bItems.values.first is Map
              ? (bItems.values.first['item'] ?? '')
              .toString()
              .toLowerCase()
              : '';

          result = aFirst.compareTo(bFirst);
          break;

// Total
        case 3:
          final aTotal = _totalOf(_itemMapOf(a));
          final bTotal = _totalOf(_itemMapOf(b));

          result = aTotal.compareTo(bTotal);
          break;

// Date
        case 4:
          final aDate =
              _timestampToDate(a['createdat']) ?? DateTime(1900);

          final bDate =
              _timestampToDate(b['createdat']) ?? DateTime(1900);

          result = aDate.compareTo(bDate);
          break;

        default:
          result = 0;
      }

      return _sortAscending ? result : -result;
    });
  }

// ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final filteredSalesView = _filterByDateRange(
          value.filterbundlesales(),
        );

        return Scaffold(
          backgroundColor: const Color(0xFF101624),

// -------------------------------------------------------------------
// APP BAR
// -------------------------------------------------------------------

          appBar: AppBar(
            title: const Text('Bundle Sales View List'),
            backgroundColor: const Color(0xFF101624),

            actions: [
              ReusableDatePickerWidget(
                child: const Icon(
                  Icons.calendar_today,
                  size: 25,
                ),
                onDateSelected: (selection) {
                  setState(() {
                    selectedDate = selection;
                  });
                },
              ),

              if (selectedDate != null)
                IconButton(
                  tooltip: 'Clear date filter',
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                  ),
                  onPressed: _clearDateRange,
                ),

              const SizedBox(width: 8),
            ],
          ),

// -------------------------------------------------------------------
// ADD BUTTON
// -------------------------------------------------------------------

          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BundlePage(),
                ),
              );
            },
          ),

// -------------------------------------------------------------------
// BODY
// -------------------------------------------------------------------

          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1200,
                ),
                child: Column(
                  children: [
// =========================================================
// BRANCH DROPDOWN
// =========================================================

                    DropdownButtonFormField<String?>(
                      value: (() {
                        final id = value.selectedBranch?.id;

                        if (id == null) {
                          return null;
                        }

                        final exists = value.branches.any(
                              (branch) => branch.id == id,
                        );

                        return exists ? id : null;
                      })(),

                      isExpanded: true,

                      dropdownColor: const Color(0xFF22304A),

                      style: const TextStyle(
                        color: Colors.white,
                      ),

                      decoration: InputDecoration(
                        labelText: 'Select Branch',

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

                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'All Branches',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),

                        ...{
                          for (var branch in value.branches)
                            branch.id: branch,
                        }.values.map(
                              (branch) {
                            return DropdownMenuItem<String?>(
                              value: branch.id,
                              child: Text(
                                branch.branchname,
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      onChanged: (val) {
                        setState(() {
                          _selectedBranch = val ?? '';

                          if (val == null) {
                            _selectedBranchName = '';
                          } else {
                            final branch = value.branches.firstWhere(
                                  (b) => b.id == val,
                            );

                            _selectedBranchName =
                                branch.branchname;
                          }
                        });

                        if (val == null) {
                          value.fetchbundlesales();
                        } else {
                          value.fetchbundlesales(
                            selectedBranch: val,
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 10),

// =========================================================
// SEARCH
// =========================================================

                    TextFormField(
                      cursorColor: Colors.white70,

                      onChanged: (text) {
                        searchQuery = text;
                        value.updateSearch(text);
                      },

                      style: const TextStyle(
                        color: Colors.white,
                      ),

                      decoration: const InputDecoration(
                        hintText: 'Search ...',

                        hintStyle: TextStyle(
                          color: Colors.white54,
                        ),

                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),

                        filled: true,

                        fillColor: Color(0xFF22304A),

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(8),
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

// =========================================================
// DATE INFORMATION
// =========================================================

                    if (selectedDate != null) ...[
                      Text(
                        'Filtered: '
                            '${DateFormat.yMMMd().format(selectedDate!.start)}'
                            ' - '
                            '${DateFormat.yMMMd().format(selectedDate!.end)}',

                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 6),
                    ],

                    if ((_selectedBranchName ?? '').isNotEmpty) ...[
                      Text(
                        'Bundle View for $_selectedBranchName',

                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ] else if (
                    _selectedBranch.isEmpty &&
                        value.bundleview.isNotEmpty
                    ) ...[
                        const Text(
                          'Bundle View for All Branches',

                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],

                    const SizedBox(height: 8),

// =========================================================
// CONTENT
// =========================================================

                    Expanded(
                      child: value.isloadingsalesbundle
                          ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      )
                          : value.bundleview.isEmpty
                          ? const Center(
                        child: Text(
                          'No Sales found',
                          style: TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      )
                          : filteredSalesView.isEmpty
                          ? const Center(
                        child: Text(
                          'No Sales found for the selected date range',
                          style: TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      )
                          : screenWidth > 900
                          ? _buildDesktopTable(
                        filteredSalesView,
                      )
                          : _buildMobileList(
                        filteredSalesView,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

// ===========================================================================
// DESKTOP
// ===========================================================================

  Widget _buildDesktopTable(
      List<Map<String, dynamic>> sales,
      ) {
    final columnWidths = <double>[
      40,
      190,
      300,
      110,
      100,
      110,
      220,
    ];

    final columnLabels = <String>[
      '#',
      'Name',
      'Item',
      'Total',
      'Date',
      'Enable/Disable',
      'Action',
    ];

    final totalWidth =
        columnWidths.fold<double>(
          0,
              (sum, width) => sum + width,
        ) +
            ((columnWidths.length - 1) * 10) +
            30;

    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      trackVisibility: true,

      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,

        child: SizedBox(
          width: totalWidth,

          child: Column(
            children: [
// ===============================================================
// HEADER
// ===============================================================

              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                ),

                color: const Color(0xFF22304A),

                child: Row(
                  children: List.generate(
                    columnLabels.length,
                        (index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right:
                          index == columnLabels.length - 1
                              ? 0
                              : 10,
                        ),

                        child: _buildHeaderCell(
                          index,
                          columnLabels[index],
                          columnWidths[index],
                          sales,
                        ),
                      );
                    },
                  ),
                ),
              ),

// ===============================================================
// DATA
// ===============================================================

              Expanded(
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  trackVisibility: true,

                  child: ListView.builder(
                    controller: _verticalController,
                    itemCount: sales.length,

                    itemBuilder: (context, index) {
                      return _buildDesktopRow(
                        sales[index],
                        index,
                        columnWidths,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// ---------------------------------------------------------------------------
// HEADER CELL
// ---------------------------------------------------------------------------

  Widget _buildHeaderCell(
      int index,
      String label,
      double width,
      List<Map<String, dynamic>> sales,
      ) {
    final sortable =
        index == 1 ||
            index == 2 ||
            index == 3 ||
            index == 4;

    final active = _sortColumnIndex == index;

    Widget content = Text(
      label,

      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
    );

    if (sortable && active) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,

          const SizedBox(width: 4),

          Icon(
            _sortAscending
                ? Icons.arrow_upward
                : Icons.arrow_downward,

            color: Colors.white70,
            size: 14,
          ),
        ],
      );
    }

    return SizedBox(
      width: width,

      child: sortable
          ? InkWell(
        onTap: () {
          _sortSales(
            sales,
            index,
          );
        },

        child: Align(
          alignment: Alignment.centerLeft,
          child: content,
        ),
      )
          : Align(
        alignment: Alignment.centerLeft,
        child: content,
      ),
    );
  }

// ---------------------------------------------------------------------------
// DESKTOP ROW
// ---------------------------------------------------------------------------

  Widget _buildDesktopRow(
      Map<String, dynamic> salesView,
      int index,
      List<double> columnWidths,
      ) {
    final id = salesView['id']?.toString() ?? '';

    final name =
        salesView['name']?.toString() ?? '';

    final itemMap = _itemMapOf(
      salesView,
    );

    final firstItem =
    itemMap.values.isNotEmpty &&
        itemMap.values.first is Map
        ? Map<String, dynamic>.from(
      itemMap.values.first,
    )
        : <String, dynamic>{};

    final itemName =
        firstItem['item']?.toString() ?? name;

    final itemsSummary = itemMap.values
        .whereType<Map>()
        .map(
          (item) =>
      '${item['item'] ?? ''}'
          '(${item['quantity'] ?? 0})',
    )
        .join(', ');

    final total = _totalOf(itemMap);

    final date = _formatDate(
      salesView['createdat'],
    );

    final cells = <Widget>[
      Text(
        '${index + 1}',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      ),

      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),

      Text(
        itemsSummary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),

      Text(
        NumberFormat('#,##0.00').format(total),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),

      Text(
        date,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),

      Align(
        alignment: Alignment.centerLeft,

        child: Switch(
          value: salesView['isActive'] == true,

          activeColor: Colors.green,

          onChanged: (val) {
            context.read<Datafeed>().toggleItemActive(
              docId: id,
              newStatus: val,
            );
          },
        ),
      ),

      Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          IconButton(
            tooltip: 'Edit',

            icon: const Icon(
              Icons.edit,
              color: Colors.blueAccent,
              size: 18,
            ),

            onPressed: () {
              final itemList = itemMap.values
                  .whereType<Map>()
                  .map(
                    (item) =>
                Map<String, dynamic>.from(item),
              )
                  .toList();

              _handleEdit(
                context,
                id,
                itemList,
              );
            },
          ),

          IconButton(
            tooltip: 'Delete',

            icon: const Icon(
              Icons.delete,
              color: Colors.redAccent,
              size: 18,
            ),

            onPressed: () {
              _handleDelete(
                context,
                itemName,
                id,
              );
            },
          ),
        ],
      ),
    ];

    return Container(
      constraints: const BoxConstraints(
        minHeight: 58,
      ),

      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 6,
      ),

      color: index.isEven
          ? const Color(0xFF0D1B2A)
          : const Color(0xFF10192B),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,

        children: List.generate(
          columnWidths.length,
              (i) {
            return Padding(
              padding: EdgeInsets.only(
                right:
                i == columnWidths.length - 1
                    ? 0
                    : 10,
              ),

              child: SizedBox(
                width: columnWidths[i],

                child: Align(
                  alignment: Alignment.centerLeft,
                  child: cells[i],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

// ===========================================================================
// MOBILE
// ===========================================================================

  Widget _buildMobileList(
      List<Map<String, dynamic>> sales,
      ) {
    return ListView.separated(
      padding: const EdgeInsets.only(
        bottom: 80,
      ),

      itemCount: sales.length,

      separatorBuilder: (_, __) {
        return const SizedBox(
          height: 12,
        );
      },

      itemBuilder: (context, index) {
        return _buildMobileCard(
          sales[index],
          index,
        );
      },
    );
  }

// ---------------------------------------------------------------------------
// MOBILE CARD
// ---------------------------------------------------------------------------

  Widget _buildMobileCard(
      Map<String, dynamic> salesView,
      int index,
      ) {
    final id =
        salesView['id']?.toString() ?? '';

    final name =
        salesView['name']?.toString() ?? '';

    final itemMap =
    _itemMapOf(salesView);

    final firstItem =
    itemMap.values.isNotEmpty &&
        itemMap.values.first is Map
        ? Map<String, dynamic>.from(
      itemMap.values.first,
    )
        : <String, dynamic>{};

    final itemName =
        firstItem['item']?.toString() ?? '';

    final totalAmount =
    _totalOf(itemMap);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 4,
      ),

      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),

        borderRadius: BorderRadius.circular(
          20,
        ),

        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          20,
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
// ================================================================
// HEADER
// ================================================================

            Container(
              padding: const EdgeInsets.all(16),

              color: Colors.white.withOpacity(
                0.03,
              ),

              child: Wrap(
                spacing: 8,
                runSpacing: 6,

                crossAxisAlignment:
                WrapCrossAlignment.center,

                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.amberAccent
                          .withOpacity(0.1),

                      borderRadius:
                      BorderRadius.circular(
                        8,
                      ),
                    ),

                    child: Text(
                      'Name #$name',

                      style: const TextStyle(
                        color:
                        Colors.amberAccent,
                        fontSize: 14,
                        fontWeight:
                        FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                  Text(
                    '#: ${index + 1}',

                    style: TextStyle(
                      color:
                      Colors.white.withOpacity(
                        0.5,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

// ================================================================
// BODY
// ================================================================

            Padding(
              padding: const EdgeInsets.all(
                16,
              ),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  ...itemMap.values.map(
                        (rawItem) {
                      if (rawItem is! Map) {
                        return const SizedBox();
                      }

                      final item =
                      Map<String, dynamic>.from(
                        rawItem,
                      );

                      return _buildMobileItem(
                        item,
                      );
                    },
                  ),

                  const Divider(
                    color: Colors.white24,
                  ),

                  const SizedBox(height: 8),

// STAFF
                  _buildFooterLabel(
                    Icons.person_outline,
                    'Staff: '
                        '${salesView['staff'] ?? ''}',
                  ),

                  const SizedBox(height: 6),

// DATE
                  _buildFooterLabel(
                    Icons.calendar_today_outlined,
                    'Date: '
                        '${_formatDateTime(salesView['createdat'])}',
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'TOTAL AMOUNT',

                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    'GHC '
                        '${NumberFormat("#,##0.00").format(totalAmount)}',

                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

// ================================================================
// ACTIONS
// ================================================================

            Container(
              color: Colors.black26,

              padding:
              const EdgeInsets.symmetric(
                horizontal: 8,
              ),

              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      Icons.edit,
                      'Edit',
                      Colors.blueAccent,
                          () {
                        final itemList =
                        itemMap.values
                            .whereType<Map>()
                            .map(
                              (item) =>
                          Map<String,
                              dynamic>.from(
                            item,
                          ),
                        )
                            .toList();

                        _handleEdit(
                          context,
                          id,
                          itemList,
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 5),

                  Expanded(
                    child: _buildActionButton(
                      Icons.delete_outline,
                      'Delete',
                      Colors.redAccent,
                          () {
                        _handleDelete(
                          context,
                          itemName,
                          id,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

// ================================================================
// ACTIVE SWITCH
// ================================================================

            SwitchListTile(
              dense: true,

              title: const Text(
                'Active',
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),

              value:
              salesView['isActive'] == true,

              activeColor: Colors.green,

              onChanged: (val) {
                context
                    .read<Datafeed>()
                    .toggleItemActive(
                  docId: id,
                  newStatus: val,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

// ---------------------------------------------------------------------------
// MOBILE ITEM
// ---------------------------------------------------------------------------

  Widget _buildMobileItem(
      Map<String, dynamic> item,
      ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: Colors.black12,

        borderRadius:
        BorderRadius.circular(12),
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Text(
            item['item']
                ?.toString()
                .toUpperCase() ??
                '',

            maxLines: 2,
            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              color: Colors.white,
              fontWeight:
              FontWeight.w800,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'GHC ${item['totalamount'] ?? 0}',

            style: const TextStyle(
              color: Colors.white70,
              fontWeight:
              FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const Divider(
            color: Colors.white10,
            height: 20,
          ),

          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
            },

            children: [
              _buildTableRow(
                'Qty',
                '${item['quantity'] ?? 0}'
                    ' (${item['mode'] ?? ''})',
              ),

              _buildTableRow(
                'Price',
                'GHC ${item['price'] ?? 0}',
              ),

              _buildTableRow(
                'Price mode',
                capitalize(
                  item['pricemode']?.toString(),
                ),
              ),

              if (item['cp'] != null)
                _buildTableRow(
                  'Cost Price',
                  'GHC ${item['cp']}',
                ),

              if (item['barcode'] != null)
                _buildTableRow(
                  'Barcode',
                  '${item['barcode']}',
                ),
            ],
          ),
        ],
      ),
    );
  }

// ===========================================================================
// SMALL WIDGET HELPERS
// ===========================================================================

  TableRow _buildTableRow(
      String label,
      String value,
      ) {
    return TableRow(
      children: [
        Padding(
          padding:
          const EdgeInsets.symmetric(
            vertical: 3,
          ),

          child: Text(
            label,

            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ),

        Padding(
          padding:
          const EdgeInsets.symmetric(
            vertical: 3,
          ),

          child: Text(
            value,

            maxLines: 2,
            overflow:
            TextOverflow.ellipsis,

            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight:
              FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLabel(
      IconData icon,
      String text,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.center,

      children: [
        Icon(
          icon,
          color: Colors.white38,
          size: 14,
        ),

        const SizedBox(width: 5),

        Expanded(
          child: Text(
            text,

            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,

            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      IconData icon,
      String label,
      Color color,
      VoidCallback onTap,
      ) {
// IMPORTANT:
// Do NOT wrap the label in Flexible here.
//
// TextButton.icon already uses an internal Row/Flexible arrangement.
// Wrapping the Text in Flexible can create:
//
// Flexible -> Flexible -> Text
//
// which causes:
// "Competing ParentDataWidgets are providing parent data"

    return TextButton(
      onPressed: onTap,

      style: TextButton.styleFrom(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 10,
        ),

        minimumSize:
        const Size(0, 44),

        tapTargetSize:
        MaterialTapTargetSize.shrinkWrap,
      ),

      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.center,

        mainAxisSize:
        MainAxisSize.min,

        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),

          const SizedBox(width: 6),

          Text(
            label,

            style: TextStyle(
              color: color,
              fontSize: 13,
            ),

            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

// ===========================================================================
// DELETE
// ===========================================================================

  Future<void> _handleDelete(
      BuildContext context,
      String itemName,
      String id,
      ) async {
    final confirm =
    await showDialog<bool>(
      context: context,

      builder: (innerContext) {
        return AlertDialog(
          backgroundColor:
          const Color(0xFF1B263B),

          title: Text(
            'Delete $itemName?',

            style: const TextStyle(
              color: Colors.white,
            ),
          ),

          content: Text(
            'This action cannot be undone. '
                'Are you sure?',

            style: TextStyle(
              color: Colors.white
                  .withOpacity(0.7),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  innerContext,
                  false,
                );
              },

              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ),

            ElevatedButton(
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                Colors.redAccent,
              ),

              onPressed: () {
                Navigator.pop(
                  innerContext,
                  true,
                );
              },

              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await context
          .read<Datafeed>()
          .deletebundleview(id);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '$itemName deleted successfully',style: TextStyle(color: Colors.white),
          ),

          backgroundColor:
          Colors.green,

          behavior:
          SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to delete item',
            style: TextStyle(
              color: Colors.white,
            ),
          ),

          backgroundColor:
          Colors.redAccent,

          behavior:
          SnackBarBehavior.floating,
        ),
      );
    }
  }

// ===========================================================================
// EDIT
// ===========================================================================

  Future<void> _handleEdit(
      BuildContext context,
      String id,
      List<Map<String, dynamic>> items,
      ) async {
    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (context) {
          return BundlePage(
            docId: id,
            item: items,
          );
        },
      ),
    );
  }
}

