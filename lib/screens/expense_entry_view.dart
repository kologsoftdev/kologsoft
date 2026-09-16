import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/appModuls.dart';
import 'package:kologsoft/models/expense_entry_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/screens/expense_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

class ExpenseEntryView extends StatefulWidget {
  const ExpenseEntryView({super.key});

  @override
  State<ExpenseEntryView> createState() => _ExpenseEntryViewState();
}

class _ExpenseEntryViewState extends State<ExpenseEntryView> {
  List<ExpenseEntryModel> expenseList = [];
  List<ExpenseEntryModel> _visibleExpenses = [];
  DateTimeRange? _selectedDateRange;

  final FirebaseFirestore db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  late Future<List<ExpenseEntryModel>> _expensesFuture;

  Future<List<ExpenseEntryModel>> _getExpenses() async {
    final datafeed = context.read<Datafeed>();
    final snapshot = await db.collection('expenses').get();

    return snapshot.docs
        .map((doc) {
      final data = doc.data();
      data['id'] = (data['id'] ?? '').toString().isNotEmpty
          ? data['id']
          : doc.id;
      return ExpenseEntryModel.fromJson(data);
    })
        .where((expense) =>
    expense.deletedby.isEmpty &&
        (datafeed.companyid.isEmpty ||
            expense.companyid == datafeed.companyid))
        .toList()
      ..sort((a, b) {
        final aDate = a.expenseDate ?? a.date ?? DateTime(1900);
        final bDate = b.expenseDate ?? b.date ?? DateTime(1900);
        return bDate.compareTo(aDate); // Most recent first
      });
  }

  // Stream<List<ExpenseEntryModel>> fetchExpenses() {
  //   return FirebaseFirestore.instance
  //       .collection('expenses')
  //       .snapshots()
  //       .map((snapshot) {
  //     return snapshot.docs.map((doc) {
  //       return ExpenseEntryModel.fromJson(doc.data());
  //     }).toList();
  //   });
  // }


  Future<void> getAll() async {
    try {
      final datafeed = context.read<Datafeed>();
      Query<Map<String, dynamic>> query = db.collection('expenses').where('companyId', isEqualTo: datafeed.companyid);
      if (datafeed.accesslevel.toLowerCase() != 'super admin' && datafeed.branchid.isNotEmpty) {
        query = query.where('branchId', isEqualTo: datafeed.branchid);
      }
      final news = await query.get();
      expenseList = news.docs.map((doc) {
        final data = doc.data();
        data['id'] = (data['id'] ?? '').toString().isNotEmpty ? data['id'] : doc.id;
        return ExpenseEntryModel.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error loading expenses: $e');
    }
  }

  void _refreshExpenses() {
    setState(() {
      _expensesFuture = _getExpenses();
    });
  }

  @override
  void initState() {
    getAll();
    // List<String> names=["KOLOG","John","Abiro"];
    // List<int> ages=[20,24,44];
    // Map<String,dynamic> aa={"name":"koloh"};

    // final noww = fetchExpenses();
    //
    // print(noww);

    // List<Map<String,dynamic>> dd= [{"name":["DON","PAPA"]},{"name":"Dan"},{"name":"Adamu"}];
    // for(var namesdata in dd){
    //   try{
    //     dd.sort();
    //     print(dd);
    //   }catch(e){
    //     print(e);
    //
    //   }
    //
    // }


    super.initState();
    _expensesFuture = _getExpenses();

  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(ExpenseEntryModel expense, String query) {
    if (query.isEmpty) {
      return true;
    }
    final normalized = query.toLowerCase();
    return expense.expenseName.toLowerCase().contains(normalized) ||
        expense.category.toLowerCase().contains(normalized) ||
        expense.vendorName.toLowerCase().contains(normalized) ||
        expense.description.toLowerCase().contains(normalized) ||
        expense.receiptNumber.toLowerCase().contains(normalized);
  }

  List<ExpenseEntryModel> _filterExpenses(List<ExpenseEntryModel> source) {
    final query = _searchController.text.trim();
    final filtered = source.where((expense) {
      final matchesQuery = _matchesSearch(expense, query);
      final expenseDate = expense.expenseDate ?? expense.date;
      final matchesDate = _selectedDateRange == null ||
          (expenseDate != null &&
              !expenseDate.isBefore(_selectedDateRange!.start) &&
              !expenseDate.isAfter(_selectedDateRange!.end));
      return matchesQuery && matchesDate;
    }).toList();

    filtered.sort((a, b) {
      final aDate = a.expenseDate ?? a.date ?? DateTime(1900);
      final bDate = b.expenseDate ?? b.date ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      initialEntryMode: DatePickerEntryMode.calendar,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF182232),
              onSurface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFF101624),
            dialogBackgroundColor: const Color(0xFF182232),
            textTheme: ThemeData.dark().textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
              child: Material(color: Colors.transparent, child: child!),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _downloadExpenses(List<ExpenseEntryModel> expenses) async {
    final rows = [
      ['Date', 'Expense', 'Category', 'Vendor', 'Amount', 'Payment Method', 'Receipt', 'Description'],
      ...expenses.map((expense) {
        final expenseDate = expense.expenseDate ?? expense.date ?? DateTime.now();
        return [
          DateFormat('yyyy-MM-dd').format(expenseDate),
          expense.expenseName,
          expense.category,
          expense.vendorName,
          expense.amount.toStringAsFixed(2),
          expense.paymentMethod,
          expense.receiptNumber,
          expense.description,
        ];
      }),
    ];

    final csv = rows
        .map((row) => row
            .map((cell) => '"${cell.toString().replaceAll('"', '""')}"')
            .join(','))
        .join('\n');

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/expenses_${DateFormat('yyyyMMdd_Hmmss').format(DateTime.now())}.csv');
    await file.writeAsString(csv);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloaded to ${file.path}')),
    );

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Expense Entries'));
  }

  Future<void> _printExpenses(
      List<ExpenseEntryModel> expenses,
      ) async {
    final datafeed = context.read<Datafeed>();

    final pdf = pw.Document();

    final totalAmount = expenses.fold<double>(
      0,
          (sum, e) => sum + e.amount,
    );

    /// Group totals by category
    final Map<String, double> categoryTotals = {};

    for (final e in expenses) {
      categoryTotals.update(
        e.category,
            (value) => value + e.amount,
        ifAbsent: () => e.amount,
      );
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(30),
        footer: (context) {
          return pw.Column(
            children: [
              pw.Divider(),
              pw.Row(
                mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              )
            ]
          );
        },
        header: (context) {
          return pw.Column(
            children: [
              pw.Text(
                datafeed.company,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  'EXPENSE ENTRIES REPORT',
                  style: const pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.grey700,
                  ),
                ),
              ),

              pw.SizedBox(height: 15),
              pw.Divider(),
            ],
          );
        },
        build: (context) {
          return [
            /// =========================
            /// COMPANY NAME
            /// =========================
            // pw.Center(
            //   child: pw.Text(
            //     datafeed.company,
            //     style: pw.TextStyle(
            //       fontSize: 24,
            //       fontWeight: pw.FontWeight.bold,
            //       color: PdfColors.blue900,
            //     ),
            //   ),
            // ),
            //
            // pw.SizedBox(height: 5),
            //
            // /// =========================
            // /// TITLE
            // /// =========================
            // pw.Center(
            //   child: pw.Text(
            //     'EXPENSE ENTRIES REPORT',
            //     style: const pw.TextStyle(
            //       fontSize: 18,
            //       color: PdfColors.grey700,
            //     ),
            //   ),
            // ),
            //
            // pw.SizedBox(height: 15),
            // pw.Divider(),

            /// =========================
            /// LEFT & RIGHT INFO
            /// =========================
            pw.Row(
              mainAxisAlignment:
              pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment:
              pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      'Report:',
                      'Expense Entries',
                    ),
                    _infoRow(
                      'Records:',
                      '${expenses.length}',
                    ),
                    _infoRow(
                      'Company:',
                      datafeed.company,
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      'Branch:',
                      datafeed.branch,
                    ),
                    _infoRow(
                      'Date:',
                      DateFormat(
                        'dd MMM yyyy',
                      ).format(DateTime.now()),
                    ),
                    _infoRow(
                      'Staff:',
                      datafeed.staff,
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 25),

            /// =========================
            /// TABLE
            /// =========================
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
              ),
              headerDecoration:
              const pw.BoxDecoration(
                color: PdfColors.blue50,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
                fontSize: 10,
              ),
              cellStyle:
              const pw.TextStyle(fontSize: 9),
              headers: const [
                'Date',
                'Invoice',
                'Expense Name',
                'Vendor',
                'Category',
                //'Payment Method',
                'Payment Account',
                'Amount',
              ],
              data: expenses.map((e) {
                final expenseDate =
                    e.expenseDate ??
                        e.date ??
                        DateTime.now();

                return [
                  DateFormat(
                    'dd/MM/yyyy',
                  ).format(expenseDate),
                  e.createdAtTimestamp,
                  e.expenseName,
                  e.vendorName,
                  e.category,
                  //e.paymentMethod,
                  e.subAccountName,
                  NumberFormat.currency(
                    symbol: 'GHC ',
                  ).format(e.amount),
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 20),

            /// =========================
            /// TOTAL BOX
            /// =========================
            pw.Align(
              alignment:
              pw.Alignment.centerRight,
              child: pw.Container(
                width: 280,
                padding:
                const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey300,
                  ),
                  borderRadius:
                  pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment:
                      pw.MainAxisAlignment
                          .spaceBetween,
                      children: [
                        pw.Text(
                          'Total Records:',
                          style: pw.TextStyle(
                            fontWeight:
                            pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '${expenses.length}',
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment:
                      pw.MainAxisAlignment
                          .spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL:',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight:
                            pw.FontWeight.bold,
                            color:
                            PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          NumberFormat.currency(
                            symbol: 'GHC ',
                          ).format(totalAmount),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight:
                            pw.FontWeight.bold,
                            color:
                            PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // pw.SizedBox(height: 30),
            //
            // /// =========================
            // /// GRAND TOTAL BY CATEGORY
            // /// =========================
            // pw.Text(
            //   'GRAND TOTAL BY CATEGORY',
            //   style: pw.TextStyle(
            //     fontSize: 14,
            //     fontWeight: pw.FontWeight.bold,
            //     color: PdfColors.blue900,
            //   ),
            // ),
            //
            // pw.SizedBox(height: 10),
            //
            // pw.TableHelper.fromTextArray(
            //   border: pw.TableBorder.all(
            //     color: PdfColors.grey300,
            //   ),
            //   headerDecoration:
            //   const pw.BoxDecoration(
            //     color: PdfColors.blue50,
            //   ),
            //   headers: const [
            //     'Category',
            //     'Amount',
            //   ],
            //   data: categoryTotals.entries
            //       .map(
            //         (e) => [
            //       e.key,
            //       NumberFormat.currency(
            //         symbol: 'GHC ',
            //       ).format(e.value),
            //     ],
            //   )
            //       .toList(),
            // ),
            //
            // pw.SizedBox(height: 40),
            //
            // pw.Divider(),
            //
            // /// =========================
            // /// FOOTER
            // /// =========================
            // pw.Text(
            //   'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            //   style: const pw.TextStyle(
            //     fontSize: 9,
            //     color: PdfColors.grey600,
            //   ),
            // ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async =>
          pdf.save(),
    );
  }

  Widget _buildExpenseCard(ExpenseEntryModel expense) {
    final expenseDate = expense.expenseDate ?? expense.date ?? DateTime.now();
    final datafeed = context.read<Datafeed>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF223449),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  expense.expenseName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                NumberFormat.currency(symbol: '₵').format(expense.amount),
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Date: ${DateFormat('dd/MM/yyyy').format(expenseDate)}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Vendor: ${expense.vendorName}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Category: ${expense.category}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if(datafeed.canEdit(AppModules.accounts))
              IconButton(
                tooltip: 'Edit',
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                iconSize: 18,
                icon: const Icon(Icons.edit, color: Colors.orange),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpenseEntry(expense: expense),
                    ),
                  ).then((_) => _refreshExpenses());
                },
              ),

              IconButton(
                tooltip: 'Print',
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                iconSize: 18,
                icon: const Icon(Icons.print_outlined, color: Colors.white70),
                onPressed: () => _printExpenses([expense]),
              ),
              if(datafeed.canDelete(AppModules.accounts))
              IconButton(
                tooltip: 'Delete',
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                iconSize: 18,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: const Color(0xFF182232),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Delete Expense', style: TextStyle(color: Colors.white)),
                        content: Text('Delete ${expense.expenseName}?', style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm == true) {
                    await _deleteExpense(expense);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(ExpenseEntryModel expense) async {
    try {
      final datafeed = context.read<Datafeed>();
      expense.deletedby = datafeed.staff;
      expense.deletedat = DateTime.now();

      await db.collection('expenses').doc(expense.id).update({
        'deletedby': expense.deletedby,
        'deletedat': expense.deletedat?.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _refreshExpenses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  Future<void> _printExpenseInvoice(ExpenseEntryModel expense) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              /// Company Name
              pw.Center(
                child: pw.Text(
                  expense.companyName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),

              pw.SizedBox(height: 5),

              pw.Center(
                child: pw.Text(
                  'EXPENSE ENTRY INVOICE',
                  style: const pw.TextStyle(
                    fontSize: 20,
                    color: PdfColors.grey700,
                  ),
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),

              /// Header information
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                    children: [
                      _infoRow(
                        'Invoice Number:',
                        expense.createdAtTimestamp?.toString() ?? '',
                      ),
                      _infoRow(
                        'Vendor:',
                        expense.vendorName,
                      ),
                      _infoRow(
                        'Payment:',
                        expense.paymentMethod,
                      ),
                    ],
                  ),

                  pw.Column(
                    crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                    children: [
                      _infoRow(
                        'Branch:',
                        expense.branchName,
                      ),
                      _infoRow(
                        'Date:',
                        DateFormat(
                          'dd MMM yyyy',
                        ).format(DateTime.now()),
                      ),
                      _infoRow(
                        'Staff:',
                        expense.staff,
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              /// Expense table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3), // Date
                  1: const pw.FlexColumnWidth(2), // Receipt
                  2: const pw.FlexColumnWidth(3), // Expense
                  3: const pw.FlexColumnWidth(3), // Category
                  4: const pw.FlexColumnWidth(3), // Account
                  5: const pw.FlexColumnWidth(3), // Amount
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue50,
                    ),
                    children: [
                      _tableHeader('DATE'),
                      _tableHeader('RECEIPT'),
                      _tableHeader('EXPENSE'),
                      _tableHeader('CATEGORY'),
                      _tableHeader('PAYMENT ACCOUNT'),
                      _tableHeader('AMOUNT'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableCell(
                        DateFormat(
                          'dd/MM/yyyy',
                        ).format(
                          expense.expenseDate ??
                              expense.date ??
                              DateTime.now(),
                        ),
                      ),
                      _tableCell(expense.receiptNumber),
                      _tableCell(expense.expenseName),
                      _tableCell(expense.category),
                      _tableCell(expense.subAccountName),
                      _tableCell(
                        NumberFormat.currency(
                          symbol: 'GHC ',
                        ).format(expense.amount),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              /// Description
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey300,
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Description',
                      style: pw.TextStyle(
                        fontWeight:
                        pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(expense.description),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              /// Total box
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 250,
                  padding:
                  const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.grey300,
                    ),
                    borderRadius:
                    pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment:
                        pw.MainAxisAlignment
                            .spaceBetween,
                        children: [
                          pw.Text(
                            'Total Expenses:',
                            style: pw.TextStyle(
                              fontWeight:
                              pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text('1'),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment:
                        pw.MainAxisAlignment
                            .spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL:',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight:
                              pw.FontWeight.bold,
                              color:
                              PdfColors.blue900,
                            ),
                          ),
                          pw.Text(
                            NumberFormat.currency(
                              symbol: 'GHC ',
                            ).format(
                              expense.amount,
                            ),
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight:
                              pw.FontWeight.bold,
                              color:
                              PdfColors.blue900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              pw.Divider(),

              pw.Text(
                'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        title: const Text("EXPENSE ENTRIES"),
        backgroundColor: const Color(0xFF1B263B),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (_) => const ExpenseEntry(),
      //       ),
      //     ).then((_) => _refreshExpenses());
      //   },
      //   child: const Icon(Icons.add),
      // ),
      body: FutureBuilder<List<ExpenseEntryModel>>(
        future: _expensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No expenses found.",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExpenseEntry(),
                        ),
                      ).then((_) => _refreshExpenses());
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add Expense"),
                  ),
                ],
              ),
            );
          }

          final expenses = snapshot.data!;

          double amount = expenses.fold(
            0,
            (total, expense) => total + expense.amount,
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Search expenses by name, category, vendor...",
                              hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                              prefixIcon: const Icon(Icons.search, color: Colors.white54),
                              filled: true,
                              fillColor: const Color(0xFF182232),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Filter by date',
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white70,
                            backgroundColor: _selectedDateRange != null
                                ? Colors.blue.shade800.withValues(alpha: 0.45)
                                : const Color(0xFF22304A),
                            disabledForegroundColor: Colors.white30,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.white10),
                            ),
                          ),
                          icon: const Icon(Icons.calendar_month),
                          onPressed: _pickDateRange,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Print expenses',
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white70,
                            backgroundColor: const Color(0xFF22304A),
                            disabledForegroundColor: Colors.white30,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.white10),
                            ),
                          ),
                          icon: const Icon(Icons.print_outlined),
                          onPressed: () => _printExpenses(_visibleExpenses),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade700,
                          Colors.blue.shade900,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Total Expenses",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat.currency(symbol: '₵').format(amount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${expenses.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedDateRange != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filtered from ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} to ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedDateRange = null;
                              });
                            },
                            child: const Text('Clear filter', style: TextStyle(color: Colors.blueAccent)),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        final filtered = _filterExpenses(expenses);
                        _visibleExpenses = filtered;

                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text(
                              "No matching expense found.",
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF182232),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final useCards = constraints.maxWidth < 700;
                                final datafeed = context.read<Datafeed>();

                                if (useCards) {
                                  return Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF223449),
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                        ),
                                        child: const Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Expense Entries',
                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Text(
                                              'Card view',
                                              style: TextStyle(color: Colors.white70, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView.separated(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          itemCount: filtered.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                                          itemBuilder: (context, index) {
                                            return _buildExpenseCard(filtered[index]);
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF223449),
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Date',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'Invoice No.',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'Expense Name',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'Vendor',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Category',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Payment Method',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Payment Account',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Amount',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 112,
                                            child: Text(
                                              'Actions',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.separated(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                                        itemBuilder: (context, index) {
                                          final expense = filtered[index];
                                          final expenseDate = expense.expenseDate ?? expense.date ?? DateTime.now();
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    DateFormat('dd/MM/yyyy').format(expenseDate),
                                                    style: const TextStyle(color: Colors.white70),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    expense.createdAtTimestamp?.toString() ?? '',
                                                    style: const TextStyle(color: Colors.white),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    expense.expenseName,
                                                    style: const TextStyle(color: Colors.white),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    expense.vendorName,
                                                    style: const TextStyle(color: Colors.white70),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    expense.category,
                                                    style: const TextStyle(color: Colors.white70),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    expense.paymentMethod,
                                                    style: const TextStyle(color: Colors.white70),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    expense.subAccountName,
                                                    style: const TextStyle(color: Colors.white70),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    NumberFormat.currency(symbol: '₵').format(expense.amount),
                                                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 112,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if(datafeed.canEdit(AppModules.accounts))
                                                      IconButton(
                                                        tooltip: 'Edit',
                                                        padding: const EdgeInsets.all(2),
                                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                        iconSize: 18,
                                                        icon: const Icon(Icons.edit, color: Colors.orange),
                                                        onPressed: () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) => ExpenseEntry(expense: expense),
                                                            ),
                                                          ).then((_) => _refreshExpenses());
                                                        },
                                                      ),
                                                      if(datafeed.canDelete(AppModules.accounts))

                                                        IconButton(
                                                        tooltip: 'Delete',
                                                        padding: const EdgeInsets.all(2),
                                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                        iconSize: 18,
                                                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                                                        onPressed: () async {
                                                          final confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (context) {
                                                              return AlertDialog(
                                                                backgroundColor: const Color(0xFF182232),
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                title: const Text('Delete Expense', style: TextStyle(color: Colors.white)),
                                                                content: Text('Delete ${expense.expenseName}?', style: const TextStyle(color: Colors.white70)),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () => Navigator.pop(context, false),
                                                                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                                                  ),
                                                                  ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                                    onPressed: () => Navigator.pop(context, true),
                                                                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                                                  ),
                                                                ],
                                                              );
                                                            },
                                                          );

                                                          if (confirm == true) {
                                                            await _deleteExpense(expense);
                                                          }
                                                        },
                                                      ),

                                                      IconButton(
                                                        tooltip: 'Print',
                                                        padding: const EdgeInsets.all(2),
                                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                        iconSize: 18,
                                                        icon: const Icon(Icons.print_outlined, color: Colors.white70),
                                                        onPressed: () => _printExpenseInvoice(expense),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      },
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
pw.Widget _infoRow(
    String title,
    String value,
    ) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$title ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.TextSpan(text: value),
        ],
      ),
    ),
  );
}

pw.Widget _tableHeader(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
    ),
  );
}

pw.Widget _tableCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(text),
  );
}