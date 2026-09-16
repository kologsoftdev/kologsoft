
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/screens/uploadreceipt.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../providers/Datafeed.dart';


class uploadReceiptViewPage extends StatefulWidget {
  const uploadReceiptViewPage({super.key});

  @override
  State<uploadReceiptViewPage> createState() => _uploadReceiptViewPageState();
}

class _uploadReceiptViewPageState extends State<uploadReceiptViewPage> {
  String searchQuery = '';
  DateTimeRange? selectedDate;
  String _selectedBranch = '';
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _rowsPerPage = 10;

  void _sort<T>(
      Comparable<T> Function(dynamic d) getField,
      int columnIndex,
      bool ascending,
      List list,
      ) {
    list.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);

      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }
  String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask((){
      final datafeed = Provider.of<Datafeed>(context, listen: false);
      _selectedBranch = (datafeed.selectedBranch != null &&
          datafeed.selectedBranch!.branchtype != 'Warehouse')
          ? datafeed.selectedBranch!.id
          : '';
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchUploadReceipts( selectedBranch: _selectedBranch);
    });

  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {

        final filteredreceipts = value.filterUploadReceipts();

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: const Text('Receipt View List'),
            actions: [
              // ReusableDatePickerWidget(
              //   child: Icon(Icons.calendar_today, size: 25),
              //   onDateSelected: (selection) {
              //     setState(() {
              //       selectedDate = selection;
              //
              //     });
              //     context.read<Datafeed>().fetchsalesview(
              //         //selectedDate:selectedDate,
              //         selectedBranch: _selectedBranch
              //     );
              //   },
              // ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptUploadPage()),
              );
            },
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: value.selectedBranch?.id,
                      dropdownColor: const Color(0xFF22304A),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Select Branch',
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
                      items: value.branches.where((branch) => branch.branchtype != 'Warehouse').map((branch) {
                        return DropdownMenuItem<String>(
                          value: branch.id,
                          child: Text(branch.branchname),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _selectedBranch = val;
                          value.fetchUploadReceipts(selectedBranch: val);
                        }
                      },
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      onChanged: value.updateSearch,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search ...',
                        hintStyle: TextStyle(color: Colors.white54),
                        prefixIcon: Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: Color(0xFF22304A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (selectedDate != null)...[
                      const Text('Upload View List for the period of:'),
                      Text(
                        "${DateFormat.yMMMd().format(selectedDate!.start)} - ${DateFormat.yMMMd().format(selectedDate!.end)}",
                        style: const TextStyle(fontSize: 12,color: Colors.white),
                      ),
                    ],

                    Expanded(
                      child: value.isLoadingReceipt
                          ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                          : value.receiptList.isEmpty
                          ? const Center(
                        child: Text(
                          'No Upload list found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                          : LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth > 600;

                          if (isDesktop) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 900,minWidth:900),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: DataTableTheme(
                                    data: DataTableThemeData(
                                      columnSpacing: 8,
                                      headingRowColor:
                                      MaterialStateProperty.all(const Color(0xFF1B263B)),
                                      dataRowColor:
                                      MaterialStateProperty.all(const Color(0xFF0D1B2A)),
                                      headingTextStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      dataTextStyle: const TextStyle(color: Colors.white),
                                      dividerThickness: 0.5,
                                    ),
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        cardColor: const Color(0xFF0D1B2A),
                                        dividerColor: Colors.white24,
                                        iconTheme: const IconThemeData(
                                          color: Colors.white,
                                        ),
                                        canvasColor: const Color(0xFF0D1B2A),
                                        textTheme: const TextTheme(
                                          bodyMedium: TextStyle(color: Colors.white),
                                          bodySmall: TextStyle(color: Colors.white),
                                        ),

                                        colorScheme: const ColorScheme.dark(
                                          surface: Color(0xFF0D1B2A),
                                          onSurface: Colors.white,
                                        ),

                                      ),

                                      child: PaginatedDataTable(

                                        rowsPerPage: _rowsPerPage,
                                        availableRowsPerPage: const [5, 10, 20, 50,100],
                                        onRowsPerPageChanged: (value) {
                                          setState(() {
                                            _rowsPerPage = value!;
                                          });
                                        },
                                        sortColumnIndex: _sortColumnIndex,
                                        sortAscending: _sortAscending,

                                        headingRowColor:
                                        MaterialStateProperty.all(const Color(0xFF1B263B)),

                                        columns: [

                                          const DataColumn(label: Text("#")),

                                          DataColumn(
                                            label: const Text("Name"),
                                            onSort: (index, ascending) {
                                              _sort((d) => d['name'], index, ascending, filteredreceipts);
                                            },
                                          ),



                                          DataColumn(
                                            label: const Text("Staff"),
                                            onSort: (index, ascending) {
                                              _sort((d) => d["createdBy"] ?? '', index, ascending, filteredreceipts);
                                            },
                                          ),


                                          DataColumn(
                                            label: const Text("Branch"),
                                            onSort: (index, ascending) {
                                              _sort((d) => d['branch'] ?? '', index, ascending, filteredreceipts);
                                            },
                                          ),
                                          DataColumn(
                                            label: const Text("Image"),
                                            onSort: (index, ascending) {
                                              _sort((d) => d['receiptUrl'] ?? '', index, ascending, filteredreceipts);
                                            },
                                          ),
                                          DataColumn(
                                            label: const Text("Date"),
                                            onSort: (index, ascending) {
                                              _sort((d) => d['createdat'] ?? '', index, ascending, filteredreceipts);
                                            },
                                          ),
                                          const DataColumn(label: Text("Action")),
                                        ],

                                        source: ReceiptDataSource(
                                          receipts: filteredreceipts,
                                          context: context,
                                          sort: _sort,
                                          handleDelete: _handleDelete,
                                          handleEdit: _handleEdit,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          /// MOBILE
                          return ListView.separated(
                            itemCount: filteredreceipts.length,
                            separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final receipt = filteredreceipts[index];

                              final id = receipt['id'] ?? '';
                              final name = receipt['name'] ?? '';
                              final branch = receipt['branch'] ?? '';
                              final staff = receipt['staff'] ?? '';
                              final List receiptUrls = receipt['receiptUrl'] ?? [];
                              final rawDate = receipt['createdat'];

                              DateTime? parsedDate;

                              if (rawDate is Timestamp) {
                                parsedDate = rawDate.toDate();
                              } else if (rawDate is String && rawDate.isNotEmpty) {
                                parsedDate = DateTime.tryParse(rawDate);
                              }

                              final createdDate = parsedDate != null
                                  ? DateFormat('MMM dd, yyyy – hh:mm a').format(parsedDate)
                                  : '';
                              return Container(
                                margin: const EdgeInsets.symmetric( vertical: 8, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B263B),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all( color: Colors.white.withOpacity(0.05)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        color: Colors.white.withOpacity(0.03),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.amberAccent.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular( 8),),
                                              child: Text(
                                                "Name #$name",
                                                style: const TextStyle(
                                                  color: Colors.amberAccent,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text("#: ${index + 1}",
                                              style: TextStyle(
                                                  color: Colors.white.withOpacity( 0.5),
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [

                                            Center(
                                              child: Container(
                                                height: 200,
                                                width: 200,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF22304A),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.white24),
                                                ),
                                                child: receiptUrls.isEmpty
                                                    ? const Center(
                                                  child: Icon(
                                                    Icons.image_not_supported,
                                                    size: 50,
                                                    color: Colors.white38,
                                                  ),
                                                )
                                                    : ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: PageView.builder(
                                                    itemCount: receiptUrls.length,
                                                    itemBuilder: (context, index) {
                                                      final url = receiptUrls[index];

                                                      return GestureDetector(
                                                        onTap: () {
                                                          showDialog(
                                                            context: context,
                                                            builder: (_) => _ImagePreviewDialog(imageUrl: url),
                                                          );
                                                        },
                                                        child: Image.network(
                                                          url,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) {
                                                            return const Icon(
                                                              Icons.error,
                                                              color: Colors.red,
                                                            );
                                                          },
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const Divider(color: Colors.white24),


                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    _buildFooterLabel(
                                                     Icons.person_outline,
                                                     "Staff: $staff"),
                                                    const SizedBox(height: 4),
                                                    _buildFooterLabel(
                                                      Icons.calendar_today_outlined,
                                                      "Date: $createdDate",
                                                    ),
                                                  ],
                                                ),

                                              ],
                                            ),
                                          ],
                                        ),
                                      ),


                                      Container(
                                        color: Colors.black26,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            Text("Branch: $branch",
                                                style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 10)
                                            ),
                                            Visibility(
                                              visible: value.canEdit(AppModules.accounts),
                                              child: _buildActionButton(
                                                Icons.edit, "Edit",
                                                Colors.blueAccent,
                                                () {
                                                  _handleEdit(context, id, receipt);
                                              },
                                            ),
                                            ),
                                            Visibility(
                                              visible: value.canDelete(AppModules.accounts),
                                              child: _buildActionButton(
                                                Icons.delete_outline, "Delete",
                                                Colors.redAccent, () =>
                                                _handleDelete(context, name, id,receiptUrls),
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
                        },
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

  }


  Widget _buildFooterLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }
  Future<void> _handleDelete(BuildContext context, String name, String id,List url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: Text(
            "Delete $name?",
            style: const TextStyle(color: Colors.white)
        ),
        content: Text(
          "This action cannot be undone. Are you sure?",
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(innerContext, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Accessing the provider
        await context.read<Datafeed>().deleteUploadReceipt(id,url);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$name deleted successfully"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to delete item"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
  Future<void> _handleEdit( BuildContext context, String id,    Map<String, dynamic> item, ) async {
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptUploadPage(
          docId: id,
          item: item,
        ),
      ),
    );
  }

}

class ReceiptDataSource extends DataTableSource {
  final List<Map<String, dynamic>> receipts;
  final BuildContext context;
  final Function sort;
  final Function handleDelete;
  final Function handleEdit;

  ReceiptDataSource({
    required this.receipts,
    required this.context,
    required this.sort,
    required this.handleDelete,
    required this.handleEdit,
  });

  @override
  DataRow getRow(int index) {
    final r = receipts[index];
    final List urls = r['receiptUrl'] ?? [];

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text("${index + 1}")),


        DataCell(Text(r['name'])),

        DataCell( Text(r['staff']) ),


        DataCell(Text("${r['branch'] ?? ''}")),


        // DataCell(
        //   Row(
        //     children: (r['receiptUrl'] as List<dynamic>? ?? [])
        //         .take(3)
        //         .map((url) => Padding(
        //       padding: const EdgeInsets.all(4),
        //       child: Image.network(
        //         url,
        //         width: 40,
        //         height: 40,
        //         fit: BoxFit.cover,
        //       ),
        //     ))
        //         .toList(),
        //   ),
        // ),
        DataCell(
          Row(
            children: (r['receiptUrl'] as List<dynamic>? ?? [])
                .take(3)
                .map((url) => Padding(
              padding: const EdgeInsets.all(4),
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => _ImagePreviewDialog(imageUrl: url),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Image.network(
                    url,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ))
                .toList(),
          ),
        ),
        DataCell(Text(
          r['createdat'] != null
              ? (r['createdat'] as Timestamp)
              .toDate()
              .toString()
              .split(' ')
              .first
              : '',
        )),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                onPressed:  () {

                  handleEdit(context,r['id'], r);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => handleDelete(context,r['name'], r['id'],urls),
              ),
            ],
          ),


        ),
      ],
    );
  }

  @override
  int get rowCount => receipts.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

class _ImagePreviewDialog extends StatelessWidget {
  final String imageUrl;

  const _ImagePreviewDialog({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            child: Image.network(imageUrl),
          ),

          //Close button
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}