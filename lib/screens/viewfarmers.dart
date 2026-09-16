import 'package:flutter/material.dart';
import '../models/appModuls.dart';
import '../models/farmerModel.dart';
import '../providers/Datafeed.dart';
import 'package:provider/provider.dart';
import '../providers/StockProvider.dart';
import 'farmer_reg.dart';
class FarmerListPage extends StatefulWidget {
  const FarmerListPage({super.key});

  @override
  State<FarmerListPage> createState() => _FarmerListPageState();
}

class _FarmerListPageState extends State<FarmerListPage> {
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<StockProvider>().fetchFarmers();
    });
  }

  List<FarmerRegModel> _filteredCustomerlist(List<FarmerRegModel> customers) {
    if (searchQuery.isEmpty) {
      return List<FarmerRegModel>.from(customers);
    }

    final query = searchQuery.toLowerCase();

    return customers.where((c) {
      return [
        c.name,
        c.popularname,
        c.farmerid,
        c.contact,
        c.customertype,
        c.branchname,
        c.paymentduration,
        c.staff,
        c.majorcrop,
        c.community,
      ].any((field) => (field ?? '').toLowerCase().contains(query));
    }).toList();
  }

  void _showFarmerDetailsBottomSheet(FarmerRegModel farmer) {
    final isDark = true;
    final textColor = Colors.white;
    final subtitleColor = Colors.white70;
    final cardColor = const Color(0xFF1B263B);
    final accentColor = const Color(0xFF415A77);
    final highlightColor = const Color(0xFFE0A800);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121927),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              // Header with farmer name and close button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF415A77), Color(0xFF1B263B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          farmer.name.isNotEmpty ? farmer.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farmer.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'aka "${farmer.popularname}"',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.agriculture, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text(
                                farmer.farmerid,
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Personal Information Section
                    _buildSectionHeader(Icons.person, 'Personal Information'),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Full Name',
                      farmer.name,
                      Icons.person_outline,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Popular Name',
                      farmer.popularname,
                      Icons.people_alt,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Farmer ID',
                      farmer.farmerid,
                      Icons.badge,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Gender',
                      farmer.gender,
                      farmer.gender == 'Male' ? Icons.male : Icons.female,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Date of Birth',
                      farmer.dateofbirth,
                      Icons.cake,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Education Level',
                      farmer.educationlevel,
                      Icons.school,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Ghana Card',
                      farmer.ghanacard,
                      Icons.credit_card,
                      textColor,
                      subtitleColor,
                    ),

                    const SizedBox(height: 24),
                    // Contact & Location Section
                    _buildSectionHeader(Icons.location_on, 'Contact & Location'),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Phone',
                      farmer.contact,
                      Icons.phone,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Home Address',
                      farmer.homeaddress,
                      Icons.home,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'GPS Coordinates',
                      "${farmer.homegps}",
                      Icons.location_on,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Community',
                      farmer.community,
                      Icons.location_city,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'District',
                      farmer.district,
                      Icons.map,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Region',
                      farmer.region,
                      Icons.public,
                      textColor,
                      subtitleColor,
                    ),

                    const SizedBox(height: 24),
                    // Farming Information Section
                    _buildSectionHeader(Icons.eco, 'Farming Information'),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Business Name',
                      farmer.businessname ?? '—',
                      Icons.store,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Business Address',
                      farmer.businessaddress ?? '—',
                      Icons.location_city,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'coordinates',
                      "${farmer.businessgps}",
                      Icons.location_on,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Major Crop',
                      farmer.majorcrop,
                      Icons.agriculture,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoChipRow(
                      'Minor Crops',
                      farmer.minorcrop,
                      Icons.grass,
                      textColor,
                      subtitleColor,
                      cardColor,
                    ),
                    _buildInfoRow(
                      'Household Size',
                      farmer.household,
                      Icons.family_restroom,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Languages Spoken',
                      farmer.languagespokens.join(', '),
                      Icons.chat,
                      textColor,
                      subtitleColor,
                    ),

                    const SizedBox(height: 24),
                    // Staff & Employment Section
                    _buildSectionHeader(Icons.people, 'Staff & Employment'),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Full-time Staff',
                      farmer.fulltimestaff ?? '0',
                      Icons.work,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Part-time Staff',
                      farmer.parttimestaff ?? '0',
                      Icons.work_outline,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Registered',
                      farmer.registered ?? 'No',
                      Icons.assignment_ind,
                      textColor,
                      subtitleColor,
                    ),

                    const SizedBox(height: 24),
                    // Financial Information Section
                    _buildSectionHeader(Icons.attach_money, 'Financial Information'),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Customer Type',
                      farmer.customertype,
                      Icons.business_center,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Payment Duration',
                      farmer.paymentduration ?? '—',
                      Icons.timer,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Amount Paid',
                      'GHS ${farmer.amountpaid ?? '0'}',
                      Icons.payments,
                      textColor,
                      subtitleColor,
                      isHighlight: true,
                      highlightColor: highlightColor,
                    ),
                    _buildInfoRow(
                      'Credit Limit',
                      'GHS ${farmer.creditlimit ?? '0'}',
                      Icons.credit_card,
                      textColor,
                      subtitleColor,
                    ),
                    if (farmer.creditBalance != null)
                      _buildInfoRow(
                        'Credit Balance',
                        'GHS ${farmer.creditBalance}',
                        Icons.account_balance_wallet,
                        textColor,
                        subtitleColor,
                      ),

                    const SizedBox(height: 24),
                    // Branch Information Section
                    _buildSectionHeader(Icons.store, 'Branch Information'),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Company',
                      farmer.companyname,
                      Icons.business,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Branch',
                      farmer.branchname,
                      Icons.storefront,
                      textColor,
                      subtitleColor,
                    ),
                    _buildInfoRow(
                      'Branch ID',
                      farmer.branchid,
                      Icons.qr_code,
                      textColor,
                      subtitleColor,
                    ),

                    const SizedBox(height: 24),
                    // Metadata Section
                    _buildSectionHeader(Icons.info, 'Record Information'),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Registered On',
                      _formatDate(farmer.date),
                      Icons.calendar_today,
                      textColor,
                      subtitleColor,
                    ),
                    if (farmer.updatedat != null)
                      _buildInfoRow(
                        'Last Updated',
                        _formatDate(farmer.updatedat!),
                        Icons.update,
                        textColor,
                        subtitleColor,
                      ),

                    const SizedBox(height: 32),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FarmerRegistration(
                                    docId: farmer.id,
                                    data: farmer,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Farmer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF415A77),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                       if(context.read<Datafeed>().canDelete(AppModules.FarmerManagement))
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Delete Farmer"),
                                  content: const Text(
                                    "Are you sure you want to delete this farmer? This action cannot be undone.",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text(
                                        "Cancel",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                if (!await context.read<Datafeed>().canDelete(AppModules.FarmerManagement)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Permission denied')),
                                  );
                                  return;
                                }
                                await context.read<Datafeed>().deleteCustomer(farmer.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Colors.green,
                                    content: Text("Farmer deleted", style: TextStyle(color: Colors.white)),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF415A77).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF778DA9)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFE0E1DD),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      String label,
      dynamic value,
      IconData icon,
      Color textColor,
      Color subtitleColor, {
        bool isHighlight = false,
        Color? highlightColor,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: subtitleColor.withOpacity(0.7)),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlight ? highlightColor : textColor,
                fontSize: 14,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChipRow(
      String label,
      List<dynamic> values,
      IconData icon,
      Color textColor,
      Color subtitleColor,
      Color cardColor,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: subtitleColor.withOpacity(0.7)),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: values.map((crop) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    crop,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final datafeed = context.watch<StockProvider>();
    final customers = datafeed.farmerlist;

    final filteredCustomers = _filteredCustomerlist(customers);

    return Scaffold(
      backgroundColor: const Color(0xFF121927),
      appBar: AppBar(
        title: const Text("Registered Farmers"),
        backgroundColor: const Color(0xFF121927),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF415A77),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FarmerRegistration(),
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
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: TextFormField(
                    cursorColor: Colors.white,
                    onChanged: (v) => setState(() => searchQuery = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search by name, farmer ID, crop, contact...',
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

                const SizedBox(height: 5),

                Expanded(
                  child: customers.isEmpty
                      ? const Center(
                    child: CircularProgressIndicator(),
                  )
                      : filteredCustomers.isEmpty
                      ? const Center(
                    child: Text(
                      'No farmers found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final farmer = filteredCustomers[index];
                      final value= Provider.of<Datafeed>(context, listen: false);

                      return Container(
                        key: ValueKey(farmer.id),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B263B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),

                            /// DETAILS - Now clickable
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showFarmerDetailsBottomSheet(farmer),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      farmer.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${farmer.farmerid}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                      Text(
                                        "Type: ${farmer.customertype}\n"
                                            "Crop: ${farmer.majorcrop}\n"
                                            "Contact: ${farmer.contact}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          height: 1.4,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if(value.canEdit(AppModules.FarmerManagement))
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.amber),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FarmerRegistration(
                                      docId: farmer.id,
                                      data: farmer,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if(value.canDelete(AppModules.FarmerManagement))

                              IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Delete farmer"),
                                    content: const Text(
                                      "Are you sure you want to delete this farmer?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text(
                                          "Cancel",
                                          style: TextStyle(color: Colors.red),
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
                                  await context.read<StockProvider>().deleteFarmer(farmer.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Colors.green,
                                      content: Text("Farmer deleted", style: TextStyle(color: Colors.white)),
                                    ),
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