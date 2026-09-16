
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/printbarcodemodel.dart';
import '../providers/Datafeed.dart';

class PrintBarcodes extends StatefulWidget {
  const PrintBarcodes({super.key});

  @override
  State<PrintBarcodes> createState() => _PrintBarcodesState();
}

class _PrintBarcodesState extends State<PrintBarcodes> {
  final TextEditingController controller =
  TextEditingController(text: "10");

  int count = 20;
  int countr = 35;
  String searchQuery = "";

  // paging (desktop table)
  int currentPage = 0;
  final int rowsPerPage = 20;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<Datafeed>().fetchProducts());
  }
  List<ProductModel> _filteredItems(List<ProductModel> items) {
    if (searchQuery.isEmpty) return items;

    final query = searchQuery.toLowerCase();
    return items.where((item) {
      final name = (item.name).toLowerCase();
      final barcode = (item.barcode).toLowerCase();
      final company = (item.company).toLowerCase();
      final category = (item.category).toLowerCase();

      return name.contains(query) || barcode.contains(query) ||
          company.contains(query) || category.contains(query); }).toList();
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<Datafeed>();
    final width = MediaQuery.of(context).size.width;
    final filteredItems = _filteredItems(provider.products);
    bool isDesktop(double width) => width > 700;
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        title: const Text("Products"),
      ),
      body: provider.loadingproducts
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : provider.products.isEmpty
          ? const Center(child: Text("No products"))
          : Column(
        children: [
          SizedBox(height: 9,),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextFormField(
                  onChanged: (v) => setState(() {
                    searchQuery = v.toLowerCase();
                    currentPage = 0;
                  }),
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
              ),
            ),
          ),
          SizedBox(height: 9,),
          Expanded(
            child: provider.loadingproducts
                ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
                : filteredItems.isEmpty
                ? const Center(
              child: Text("No items registered yet", style: TextStyle(color: Colors.white70),),
            )
                : isDesktop(width)
                ? _buildTable(filteredItems)
                : _buildMobileList(filteredItems),
          ),

        ],
      ),
    );
  }

  //  Desktop
  Widget _buildTable(List<ProductModel> filteredItems) {
    final totalPages = (filteredItems.length / rowsPerPage).ceil().clamp(1, 999999);
    if (currentPage > totalPages - 1) currentPage = totalPages - 1;
    if (currentPage < 0) currentPage = 0;

    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, filteredItems.length);
    final pageItems = filteredItems.sublist(start, end);

    const colNo = 70.0;
    const colName = 240.0;
    const colCategory = 180.0;
    const colCode = 180.0;
    const colBarcode = 100.0;
    const colQr = 100.0;

    Widget headerCell(String text, double w) => SizedBox(
      width: w,
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            // header
            Container(
              color: const Color(0xFF1B263B),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    headerCell("No", colNo),
                    headerCell("Name", colName),
                    headerCell("Category", colCategory),
                    headerCell("Code", colCode),
                    headerCell("Barcode", colBarcode),
                    headerCell("QR Code", colQr),
                  ],
                ),
              ),
            ),
          //  const Divider(height: 1, color: Colors.white24),

            // rows
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: colNo + colName + colCategory + colCode + colBarcode + colQr,
                  child: ListView.builder(
                    itemCount: pageItems.length,
                    itemBuilder: (context, index) {
                      final p = pageItems[index];
                      final barcode = (p.barcode).isEmpty ? p.name : p.barcode;
                      final rowNo = start + index + 1;

                      return Container(
                        color: const Color(0xFF0D1B2A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(width: colNo, child: Text("$rowNo", style: const TextStyle(color: Colors.white))),
                            SizedBox(width: colName, child: Text(p.name, style: const TextStyle(color: Colors.white))),
                            SizedBox(width: colCategory, child: Text(p.category, style: const TextStyle(color: Colors.white))),
                            SizedBox(width: colCode, child: Text(barcode, style: const TextStyle(color: Colors.white))),
                            SizedBox(
                              width: colBarcode,
                              child: InkWell(
                                onTap: () => previewBarcode(p),
                                child: const Icon(Icons.barcode_reader, size: 40, color: Colors.white),
                              ),
                            ),
                            SizedBox(
                              width: colQr,
                              child: InkWell(
                                onTap: () => previewQR(p),
                                child: const Icon(Icons.qr_code_scanner, size: 40, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // paging controls
            Container(
              color: const Color(0xFF1B263B),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: currentPage > 0
                        ? () => setState(() => currentPage--)
                        : null,
                  ),
                  Text(
                    "Page ${currentPage + 1} of $totalPages",
                    style: const TextStyle(color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: currentPage < totalPages - 1
                        ? () => setState(() => currentPage++)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  Mobile
  Widget _buildMobileList(List<ProductModel> filteredItems) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredItems.length,
      itemBuilder: (_, index) {
        final p = filteredItems[index];
        final barcode = (p.barcode).isEmpty ? p.name : p.barcode;

        return Card(
          color: const Color(0xFF0D1B2A),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // NAME + CATEGORY (takes remaining space)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text( p.name,  style: const TextStyle(
                          fontWeight: FontWeight.bold,color: Colors.white
                      ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.category,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // BARCODE ICON
                InkWell(
                  onTap: () => previewBarcode(p),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.barcode_reader, size: 28,color: Colors.white70),
                  ),
                ),

                const SizedBox(width: 8),

                // QR ICON (optional)
                InkWell(
                  onTap: () => previewQR(p),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.qr_code_scanner, size: 28,color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> previewBarcode(ProductModel product) async {
    final pdf = pw.Document(
      title: '${product.companyid} - ${product.name}',
    );
    final filename = '${product.company}_${product.name}.pdf';
    final monoFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/RobotoMono-Regular.ttf'),
    );
    final ttfRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );

    final ttfBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final code = product.barcode.isNotEmpty
        ? product.barcode
        : product.name;

    const int columns = 2;
    const double itemWidth = 180;
    const double itemHeight = 80;

    String formatBarcode(String code) {
      return code.split('').join(' ');
    }

    List<pw.Widget> rows = [];

    for (int i = 0; i < count; i += columns) {
      rows.add(
        pw.Row(
          children: List.generate(columns, (colIndex) {
            int index = i + colIndex;

            return pw.Expanded(
              child: index < count
                  ? pw.Container(
                height: itemHeight,
                alignment: pw.Alignment.center,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: code,
                      width: itemWidth,
                      height: 40,
                      drawText: false,
                    ),

                    pw.SizedBox(height: 6),

                    pw.Text(
                      '* ${formatBarcode(code)} *',
                      style: pw.TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        font: monoFont,
                      ),
                    ),
                  ],
                ),
              )
                  : pw.SizedBox(),
            );
          }),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(8),
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: ttfRegular,
          bold: ttfBold,
        ),
        build: (_) => rows,
      ),
    );

    final data = await pdf.save();

    await Printing.layoutPdf(
      name: filename,
      onLayout: (_) async => data,
    );
  }
  Future<void> previewQR(ProductModel product) async {
    final filename = '${product.company}_${product.name}.pdf';
    final pdf = pw.Document(title: '${product.companyid} - ${product.name}');
    final code = product.barcode.isNotEmpty ? product.barcode : product.name;
    final ttfRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );

    final ttfBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    const int columns = 5;
    const double size = 80;
    const double hSpacing = 20;
    const double vSpacing = 20;

    List<pw.Widget> rows = [];

    for (int i = 0; i < countr; i += columns) {
      rows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: vSpacing),
          child: pw.Row(
            children: List.generate(columns, (colIndex) {
              int index = i + colIndex;

              return pw.Padding(
                padding: const pw.EdgeInsets.only(right: hSpacing),
                child: index < countr
                    ? pw.Container(
                  width: size,
                  height: size,
                  alignment: pw.Alignment.center,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: code,
                  ),
                )
                    : pw.SizedBox(width: size),
              );
            }),
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: ttfRegular,
          bold: ttfBold,
        ),
        build: (_) => rows,
      ),
    );

    final data = await pdf.save();

    await Printing.layoutPdf(
      name:filename,
      onLayout: (_) async => data,
    );
  }
}
