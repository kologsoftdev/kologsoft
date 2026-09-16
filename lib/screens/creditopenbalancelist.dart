
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/creditorbalanceModel.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import 'creditopenbalance.dart';


class creditOpenBalViewPage extends StatefulWidget {
  const creditOpenBalViewPage({super.key});

  @override
  State<creditOpenBalViewPage> createState() => _creditOpenBalViewPageState();
}

class _creditOpenBalViewPageState extends State<creditOpenBalViewPage> {
  String searchQuery = '';
  DateTimeRange? selectedDate;
  String _selectedBranch = '';
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final verticalController = ScrollController();

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
    Future.microtask(() {
      context.read<Datafeed>().fetchBranches().then((_) {
        final datafeed = Provider.of<Datafeed>(context, listen: false);

        final isSystemOrSuperAdmin =
            datafeed.normalizedAccessLevelNoSpaces == 'systemadmin' ||
                datafeed.isSuperAdmin;

        setState(() {
          _selectedBranch = isSystemOrSuperAdmin ? '' : datafeed.branchid;
        });

        context.read<Datafeed>().fetchcreditoropenbal(selectedDate, _selectedBranch);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final filteredCreditorbal = value.filtercreditorBalance(searchQuery);
        final screenWidth = MediaQuery.of(context).size.width;

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: const Text('Creditor Open Balance View List'),
            actions: [
              IconButton(
                icon: const Icon(Icons.home, size: 25),
                tooltip: 'Home',
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
              ),
              ReusableDatePickerWidget(
                child: Icon(Icons.calendar_today, size: 25),
                onDateSelected: (selection) {
                  setState(() {
                    selectedDate = selection;
                  });
                  context.read<Datafeed>().fetchcreditoropenbal(selectedDate, _selectedBranch);
                },
              ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const creditOpenBalScreen()),
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
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedBranch.isEmpty ? null : _selectedBranch,
                      dropdownColor: const Color(0xFF22304A),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Select Branch',
                        labelStyle: const TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('All Branches', style: TextStyle(color: Colors.white70)),
                        ),
                        ...value.branches
                            .where((branch) => branch.branchtype != 'Warehouse')
                            .map((branch) => DropdownMenuItem<String>(
                          value: branch.id,
                          child: Text(branch.branchname),
                        )),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedBranch = val);
                          value.fetchcreditoropenbal(selectedDate, _selectedBranch);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search ...',
                        hintStyle: TextStyle(color: Colors.white54),
                        prefixIcon:
                        Icon(Icons.search, color: Colors.white54),
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
                      const Text('Close Sales View List for the period of:'),
                      Text(
                        "${DateFormat.yMMMd().format(selectedDate!.start)} - ${DateFormat.yMMMd().format(selectedDate!.end)}",
                        style: const TextStyle(fontSize: 12,color: Colors.white),
                      ),
                    ],

                    Expanded(
                      child: value.isloadingcreditbal
                          ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                          : value.creditoropenbal.isEmpty
                          ? const Center(
                        child: Text(
                          'No Creditor record  found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                          : LayoutBuilder(
                        builder: (context, constraints) {

                          if (screenWidth > 800) {
                            return Column(
                              children: [
                                _buildTableHeader(filteredCreditorbal),
                                const Divider(color: Colors.white24, height: 1),
                                Expanded(
                                  child: ScrollbarTheme(
                                    data: ScrollbarThemeData(
                                      thumbColor: MaterialStateProperty.all(
                                        const Color(0xFF415A77),
                                      ),
                                      trackColor: MaterialStateProperty.all(
                                        const Color(0xFF22304A),
                                      ),
                                      trackBorderColor: MaterialStateProperty.all(
                                        const Color(0xFF1B263B),
                                      ),
                                      thickness: MaterialStateProperty.all(10),
                                      radius: const Radius.circular(8),
                                    ),
                                    child: Scrollbar(
                                      controller: verticalController,
                                      thumbVisibility: true,
                                      trackVisibility: true,
                                      child: ListView.builder(
                                        controller: verticalController,
                                        itemCount: filteredCreditorbal.length,
                                        itemBuilder: (context, index) {
                                          return _buildTableRow(
                                            filteredCreditorbal[index],
                                            index,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          /// MOBILE
                          return ListView.separated(
                            itemCount: filteredCreditorbal.length,
                            separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final creditorinfo = filteredCreditorbal[index];

                              final id = creditorinfo.id;
                              final creditorname = creditorinfo.creditorName;
                              final amount = creditorinfo.amount;
                              // final paymentMode = creditorinfo.paymentMode;
                              // final transactionRef = creditorinfo.transactionRef;
                              final createdAt = creditorinfo.date;

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
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
                                                creditorname,
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

                                            Text("Amount: GHC $amount",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            // Text("Payment Method: $paymentMode",
                                            //    style: const TextStyle(
                                            //      color: Colors.white70,
                                            //      fontSize: 14,
                                            //    ),
                                            //  ),
                                            const SizedBox(height: 4),
                                            _buildFooterLabel(
                                              Icons.calendar_today_outlined,
                                              "Date: ${createdAt != null ? DateFormat.yMMMd().format(createdAt) : ''}",
                                            ),
                                            const SizedBox(height: 4),

                                            const Divider(color: Colors.white24),


                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                const Text("TOTAL AMOUNT",
                                                    style: TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 8)),
                                                Text(
                                                  "GHS $amount",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                  ),
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
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Expanded(child:
                                            _buildActionButton(
                                              Icons.edit, "Edit",
                                              Colors.blueAccent,
                                                  () {
                                                _handleEdit( context,
                                                  id,
                                                  creditorinfo,
                                                );
                                              },
                                            ),
                                            ),
                                           Expanded(child: _buildActionButton(
                                             Icons.delete_outline, "Delete",
                                             Colors.redAccent, () =>
                                               _handleDelete(context, creditorinfo, id),
                                           ),),

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

  Widget _buildTableHeader(List<CreditorBalance> filteredCreditorbal) {
    Widget headerCell(String label, int columnIndex, int flex, {bool numeric = false}) {
      return Expanded(
        flex: flex,
        child: InkWell(
          onTap: () {
            final ascending = _sortColumnIndex == columnIndex ? !_sortAscending : true;
            switch (columnIndex) {
              case 1:
                _sort((d) => d.creditorName ?? '', columnIndex, ascending, filteredCreditorbal);
                break;
              case 2:
                _sort((d) => d.amount, columnIndex, ascending, filteredCreditorbal);
                break;
              case 3:
                _sort((d) => d.date ?? '', columnIndex, ascending, filteredCreditorbal);
                break;
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                if (_sortColumnIndex == columnIndex)
                  Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: Colors.white,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1B263B),
      child: Row(
        children: [
          const SizedBox(width: 40, child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text("#", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )),
          headerCell("Creditor", 1, 3),
          headerCell("Amount", 2, 2, numeric: true),
          headerCell("Date", 3, 2),
          const SizedBox(
            width: 96,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Text("Action", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(CreditorBalance creditview, int index) {
    final id = creditview.id;
    final creditor = creditview.creditorName;
    final amount = creditview.amount;
    final createdAt = creditview.date;

    return Container(
      color: index.isEven ? const Color(0xFF0D1B2A) : const Color(0xFF10202F),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text("${index + 1}", style: const TextStyle(color: Colors.white)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Text(creditor, style: const TextStyle(color: Colors.white)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Text("GHC $amount",
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Text(
                createdAt != null ? DateFormat.yMMMd().format(createdAt) : '',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                  onPressed: () => _handleEdit(context, id, creditview),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                  onPressed: () => _handleDelete(context, creditview, id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLabel(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.white38,
          size: 14,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            softWrap: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
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
  Future<void> _handleDelete(BuildContext context, CreditorBalance? creditdata, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: Text(
            "Delete close sale by ${creditdata?.creditorName}?",
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
        await context.read<Datafeed>().deletecreditoropenbal(creditdata,id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${creditdata?.creditorName}'s Creditor deleted successfully",style: TextStyle(color: Colors.white),),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to delete item",style: TextStyle(color: Colors.white),),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
  Future<void> _handleEdit( BuildContext context, String id, CreditorBalance? creditdata, ) async {
    Navigator.push( context,
      MaterialPageRoute(
        builder: (context) => creditOpenBalScreen(
          docId: id,
          item: creditdata,
        ),
      ),
    );
  }

}