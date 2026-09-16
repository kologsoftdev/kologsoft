import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/dashboard_provider.dart';
import 'package:kologsoft/screens/salesTotal.dart';
import 'package:kologsoft/screens/sidebar.dart';
import 'package:kologsoft/widgets/offline_indicator.dart';
import 'package:provider/provider.dart';

import '../models/branch_stock_value.dart';
import '../models/dashboardStats.dart';
import '../models/sales_summary.dart';
import '../providers/routes.dart';
import 'companyreg.dart';
import 'debtpage.dart';
import 'expense_total.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  int _selectedIndex = 0;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async{
      final datafeed=context.read<Datafeed>();
      final dashb=context.read<DashboardProvider>();
      await datafeed.getdata();
         dashb.listenToBranchStock();
      datafeed.listenToDashboardSales();

    });
  }
  Future<void> _editCompany(BuildContext context, Datafeed datafeed) async {
    final db = FirebaseFirestore.instance;
    final doc = await db.collection('companies').doc(datafeed.companyid).get();

    if (!doc.exists) return;
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyRegPage(
          docId: doc.id,
          data: doc.data() as Map<String, dynamic>,
          isSuperAdmin: datafeed.accesslevel == 'super admin',
          isSystemAdmin: datafeed.accesslevel == 'systemadmin',
        ),
      ),
    );
  }
  void _showLogoutDialog(BuildContext parentContext, Datafeed datafeed) {
    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',style: TextStyle(color: Colors.white),),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: ()async {
                Navigator.pop(context);
               await datafeed.logout(parentContext);
                // if (!parentContext.mounted) return;
                //
                // Navigator.of(parentContext).pushNamedAndRemoveUntil(
                //   Routes.login, (_) => false,
                // );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context, Datafeed datafeed) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.lock_reset,
                                color: colorScheme.onPrimary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Change Password',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Update your account password',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: currentPasswordController,
                          obscureText: !showCurrentPassword,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: colorScheme.onPrimary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showCurrentPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              color: colorScheme.onPrimary,
                              onPressed: () {
                                setState(() {
                                  showCurrentPassword = !showCurrentPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceVariant,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter current password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: !showNewPassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: Icon(
                              Icons.lock,
                              color: colorScheme.onPrimary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              color: colorScheme.onSurfaceVariant,
                              onPressed: () {
                                setState(() {
                                  showNewPassword = !showNewPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceVariant,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                            helperText: 'Must be at least 6 characters',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter new password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: !showConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: Icon(
                              Icons.lock,
                              color: colorScheme.onPrimary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              color: colorScheme.onSurfaceVariant,
                              onPressed: () {
                                setState(() {
                                  showConfirmPassword = !showConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceVariant,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm password';
                            }
                            if (value != newPasswordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Cancel',style: TextStyle(color: Colors.white),),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                if (formKey.currentState!.validate()) {
                                  setState(() => isLoading = true);
                                  try {
                                    await datafeed.changePassword(
                                      currentPasswordController.text,
                                      newPasswordController.text,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Password changed successfully',style: TextStyle(color: ColorScheme.of(context).onPrimary),
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e',style: TextStyle(color: ColorScheme.of(context).onPrimary),),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text('Update Password'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth <= 512;
    bool isSmallTablet = screenWidth < 774;
    bool isTablet = screenWidth < 900;
    bool isMediumTablet = screenWidth < 1087;
    bool isBigTablet = screenWidth < 1200;
   // print(screenWidth);

    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            title: Text(value.company.toString().toUpperCase()),
            centerTitle: true,
            backgroundColor: const Color(0xFF0D1A26),
            foregroundColor: Colors.white,
            elevation: 2,
            actions: [
              // User menu
              PopupMenuButton<String>(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 16,
                      child: Text(
                        value.staff.isNotEmpty
                            ? value.staff[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (screenWidth > 600)
                      Text(
                        value.staff.isNotEmpty ? value.staff : 'User',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
                offset: const Offset(0, 50),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value.staff.isNotEmpty ? value.staff : 'User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        if (value.companyemail.isNotEmpty)
                          Text(
                            value.companyemail,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        const Divider(),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 20,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'My Profile',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  if (value.accesslevel == 'super admin' || value.accesslevel == 'systemadmin')
                    PopupMenuItem<String>(
                      value: 'company',
                      child: Row(
                        children: [
                          Icon(Icons.business, size: 20, color: Colors.deepPurple),
                          const SizedBox(width: 12),
                          const Text(
                            'Edit Company',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem<String>(
                    value: 'password',
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 20, color: Colors.blue),
                        const SizedBox(width: 12),
                        const Text(
                          'Change Password',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),

                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, size: 20, color: Colors.red),
                        const SizedBox(width: 12),
                        const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (String selectedValue) async {
                  if (selectedValue == 'logout') {
                    _showLogoutDialog(context, value);
                  } else if (selectedValue == 'password') {
                    _showChangePasswordDialog(context, value);
                  } else if (selectedValue == 'profile') {
                    Navigator.pushNamed(context, Routes.staffprofile);
                   } else if (selectedValue == 'company') {
                    _editCompany(context, value);
                  }
                },
              ),
            ],
          ),
          drawer: Sidebar(),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OfflineIndicator(),
                  Wrap(
                    runSpacing: 15,
                    spacing: 15,
                    children: [
                      WorkPlaceWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.47
                            : isMediumTablet
                            ? screenWidth * 0.30
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.24
                            : screenWidth * 0.23,
                      ),
                      RespWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.47
                            : isMediumTablet
                            ? screenWidth * 0.21
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.15
                            : screenWidth * 0.16,
                      ),
                      MomoKpiWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.47
                            : isMediumTablet
                            ? screenWidth * 0.21
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.15
                            : screenWidth * 0.16,
                        //todayAmount: 0.00,
                        //yesterdayAmount: 0.00,
                      ),

                      TotalDebtWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.47
                            : isMediumTablet
                            ? screenWidth * 0.21
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.15
                            : screenWidth * 0.16,
                            //totalDebt: 0.00,
                      ),

                      BranchSales(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isTablet
                            ? screenWidth * 0.98
                            : isMediumTablet
                            ? screenWidth * 0.98
                            : isBigTablet
                            ? screenWidth * 0.24
                            : screenWidth * 0.22,
                      ),
                    ],
                  ),

                  SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 85,
                    child: CarouselSlider(
                      options: CarouselOptions(
                        autoPlay: true,
                        autoPlayInterval: const Duration(seconds: 3),
                        autoPlayAnimationDuration: const Duration(milliseconds: 800),
                        enlargeCenterPage: false,
                        viewportFraction: isMobile ? 0.47 : isSmallTablet ? 0.30 : isTablet ? 0.25 : 0.15,
                        enableInfiniteScroll: true,
                        scrollDirection: Axis.horizontal,
                      ),
                      items: [
                        _statCard(
                          title: "SMS balance",
                          value: value.smsBalance.toStringAsFixed(2),
                          subtitle: "Available",
                          icon: Icons.sms,
                          iconColor: Colors.blue,
                        ),
                        _statCard(
                          title: "Total discount",
                          value: value.disCount.toStringAsFixed(2),
                          subtitle: "from sales",
                          icon: Icons.discount,
                          iconColor: Colors.deepOrange,
                        ),
                        _statCard(
                          title: "Re-order",
                          value: "0",
                          subtitle: "Requires attention",
                          icon: Icons.warning_amber_rounded,
                          iconColor: Colors.orange,
                        ),
                        _statCard(
                          title: "Expiring Soon",
                          value: "0",
                          subtitle: "Within 5 days",
                          icon: Icons.schedule,
                          iconColor: Colors.redAccent,
                        ),
                        _statCard(
                          title: "Finished Stock",
                          value: "0",
                          subtitle: "Within 30 days",
                          icon: Icons.security_update_good_sharp,
                          iconColor: Colors.lightBlue,
                        ),
                        _statCard(
                          title: "Available",
                          value: "0",
                          subtitle: "Within 30 days",
                          icon: Icons.new_label_sharp,
                          iconColor: Colors.lightGreen,
                        ),
                        _statCard(
                          title: "VAT",
                          value: "0",
                          subtitle: "Within 30 days",
                          icon: Icons.schedule,
                          iconColor: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 15),

                  Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    children: [
                      PieChartWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isTablet
                            ? screenWidth * 0.98
                            : isBigTablet
                            ? screenWidth * 0.98
                            : screenWidth * 0.35,
                      ),
                      FeedbackWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.97
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.48
                            : screenWidth * 0.20,
                      ),
                      TopWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isTablet
                            ? screenWidth * 0.97
                            : isMediumTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.48
                            : screenWidth * 0.20,
                      ),

                      MonthlyRevenueWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.97
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.48
                            : screenWidth * 0.20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FeedbackWidget extends StatelessWidget {
  final double cwidth;
  const FeedbackWidget({super.key, required this.cwidth});

  @override
  Widget build(BuildContext context) {
    return Selector<DashboardProvider, List<BranchStockItem>>(
        selector: (_, provider) => provider.branchStockValue ?? [],
        builder: (context, branchStockValue, child) {
          return Container(
            height: 400,
            width: cwidth,
            decoration: BoxDecoration(
              color: const Color(0xFF182232),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Branch Stock Value',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: branchStockValue!.length+1,
                      separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white24, height: 1),
                      itemBuilder: (context, index) {
                        if (index == branchStockValue!.length) {
                          final total = branchStockValue!.fold(0.0, (sum, item) => sum + (item.stockValue ?? 0));

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.calculate, color: Colors.amber),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    "Grand Total",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  "GHS ${NumberFormat('#,##0.00').format(total)}",

                                  //total.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final feedback = branchStockValue?[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 36,
                                width: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF3A6FF8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.house_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        feedback!.branchName!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "GHS ${NumberFormat('#,##0.00').format(feedback!.stockValue)}",
                                      //feedback!.stockValue.toStringAsFixed(2),
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
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
              ),
            ),
          );
        });
        }
  }

// dart
class PieChartWidget extends StatefulWidget {
  final double cwidth;

  const PieChartWidget({
    super.key,
    required this.cwidth,
  });

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> {
  late final Stream<WeeklySalesComparison> _salesStream;

  @override
  void initState() {
    super.initState();

    _salesStream = Provider.of<DashboardProvider>(
      context,
      listen: false,
    ).weeklySalesComparisonStream();
  }

  List<double> _normalizeWeek(List<num?>? week) {
    final w = week ?? <num?>[];

    return List<double>.generate(7, (i) {
      if (i >= w.length) return 0.0;

      final value = w[i];
      if (value == null) return 0.0;

      final d = value.toDouble();

      if (d.isNaN || d.isInfinite) {
        return 0.0;
      }

      return d;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      width: widget.cwidth,
      decoration: BoxDecoration(
        color: const Color(0xFF182232),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      clipBehavior: Clip.hardEdge,
      child: StreamBuilder<WeeklySalesComparison>(
        stream: _salesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white70,
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load weekly sales',
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'No sales data found',
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
            );
          }

          final data = snapshot.data!;

          final current = _normalizeWeek(data.currentWeek);
          final previous = _normalizeWeek(data.previousWeek);

          final currentSpots = List.generate(
            7,
                (i) => FlSpot((i + 1).toDouble(), current[i]),
          );

          final previousSpots = List.generate(
            7,
                (i) => FlSpot((i + 1).toDouble(), previous[i]),
          );

          final allValues = [
            ...current,
            ...previous,
          ];

          final rawMax = allValues.fold<double>(
            0,
                (max, e) => e > max ? e : max,
          );

          final rawMin = allValues.fold<double>(
            0,
                (min, e) => e < min ? e : min,
          );

          final paddedMax = rawMax > 0 ? rawMax * 1.15 : 10.0;
          final paddedMin = rawMin < 0 ? rawMin * 1.15 : -10.0;

          final maxY =
          ((paddedMax / 100).ceil() * 100).toDouble();

          final minY =
          ((paddedMin / 100).floor() * 100).toDouble();

          final interval = (maxY - minY) / 5;

          final useCurve = rawMax > 0 &&
              rawMax /
                  (allValues.where((e) => e > 0).length + 1) >
                  1.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Last week and current sales comparison',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    children: const [
                      _LegendDot(
                        color: Color(0xFF4FC3F7),
                        text: 'Current',
                      ),
                      SizedBox(width: 12),
                      _LegendDot(
                        color: Color(0xFFF5D76E),
                        text: 'Previous',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ClipRect(
                  child: LineChart(
                    LineChartData(
                      minX: 1,
                      maxX: 7.4,
                      minY: minY,
                      maxY: maxY,

                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) {
                            return spots.map((spot) {
                              return LineTooltipItem(
                                '${spot.barIndex == 0 ? "Current" : "Previous"}: ${spot.y.toStringAsFixed(2)}',
                                const TextStyle(
                                  color: Colors.white,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),

                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.white12,
                          strokeWidth: 1,
                        ),
                      ),

                      borderData: FlBorderData(
                        show: false,
                      ),

                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: interval,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),

                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: false,
                          ),
                        ),

                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: false,
                          ),
                        ),

                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              const style = TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              );

                              switch (value.toInt()) {
                                case 1:
                                  return const Text("Mon", style: style);
                                case 2:
                                  return const Text("Tue", style: style);
                                case 3:
                                  return const Text("Wed", style: style);
                                case 4:
                                  return const Text("Thu", style: style);
                                case 5:
                                  return const Text("Fri", style: style);
                                case 6:
                                  return const Text("Sat", style: style);
                                case 7:
                                  return const Text("Sun", style: style);
                                default:
                                  return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                      ),

                      lineBarsData: [
                        LineChartBarData(
                          spots: currentSpots,
                          isCurved: useCurve,
                          color: const Color(0xFF4FC3F7),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: previousSpots,
                          isCurved: useCurve,
                          color: const Color(0xFFF5D76E),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
class MonthlyRevenueWidget extends StatefulWidget {
  final double cwidth;

  const MonthlyRevenueWidget({
    super.key,
    required this.cwidth,
  });

  @override
  State<MonthlyRevenueWidget> createState() => _MonthlyRevenueWidgetState();
}

class _MonthlyRevenueWidgetState extends State<MonthlyRevenueWidget> {
  late final Stream<List<Map<String, dynamic>>> _topItemsStream;

  @override
  void initState() {
    super.initState();

    _topItemsStream = context
        .read<Datafeed>()
        .top10BestSellingItems('sales_value');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      width: widget.cwidth,
      decoration: BoxDecoration(
        color: const Color(0xFF182232),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Best 10 financial performing Items',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Item Name',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Amount',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            const Divider(color: Colors.white24),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _topItemsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'No data',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final items = snapshot.data!;

                  return ListView.separated(
                    key: const PageStorageKey('top10_items'),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white24, height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return Padding(
                        key: ValueKey(item['itemid']),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['item'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              " GHC ${NumberFormat('#,##0.00').format(item['sales_value'])}",
                              //'GHC ${(item['sales_value'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopWidget extends StatefulWidget {
  final double cwidth;

  const TopWidget({
    super.key,
    required this.cwidth,
  });

  @override
  State<TopWidget> createState() => _TopWidgetState();
}

class _TopWidgetState extends State<TopWidget> {
  late final Stream<List<Map<String, dynamic>>> _topItemsStream;

  @override
  void initState() {
    super.initState();

    _topItemsStream = Provider.of<Datafeed>(
      context,
      listen: false,
    ).top10BestSellingItems('sales_qty');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      width: widget.cwidth,
      decoration: BoxDecoration(
        color: const Color(0xFF182232),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Best 10 qtys Performing Items',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item Name',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Qty',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _topItemsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];

                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'No data',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white24, height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['item'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                            " ${NumberFormat('#,##0').format(item['sales_qty'])}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BranchSales extends StatefulWidget {
  final double cwidth;

  const BranchSales({
    super.key,
    required this.cwidth,
  });

  @override
  State<BranchSales> createState() => _BranchSalesState();
}

class _BranchSalesState extends State<BranchSales> {
  late final Stream<SalesSummary> _salesSummaryStream;

  @override
  void initState() {
    super.initState();

    _salesSummaryStream = Provider.of<Datafeed>(
      context,
      listen: false,
    ).StodayTotalsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, value, child) {
        return Container(
          height: 235,
          width: widget.cwidth,
          decoration: BoxDecoration(
            color: const Color(0xFF182232),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Branch Sales Today',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: StreamBuilder<SalesSummary>(
                    stream: _salesSummaryStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: Text(
                            'No sales data',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      final summary = snapshot.data!;
                      final entries =
                      summary.branchTotals.entries.toList();

                      final grandTotal = entries.fold<double>(
                        0,
                            (sum, e) => sum + e.value,
                      );

                      return ListView.separated(
                        itemCount: entries.length + 1,
                        separatorBuilder: (_, __) =>
                        const Divider(
                          color: Colors.white24,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          if (index == entries.length) {
                            return Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calculate,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      "Grand Total",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                      "GHS ${NumberFormat('#,##0.00').format(grandTotal)}",
                                   // grandTotal.toStringAsFixed(2),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final entry = entries[index];

                          return Padding(
                            padding:
                            const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  height: 36,
                                  width: 36,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3A6FF8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.house_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          overflow:
                                          TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        entry.value.toStringAsFixed(2),
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
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
class CsatWidget extends StatelessWidget {
  final double cwidth;
  const CsatWidget({super.key, required this.cwidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cwidth,
      height: 235,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF182232),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title
          Row(
            children: [
              Text(
                "CSAT",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Progress indicator (simplified version)
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Filled portion (84%)
                FractionallySizedBox(
                  widthFactor: 0.84,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Percentage
          Text(
            '84%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),

          // Labels row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                '100%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MiddleWidget extends StatelessWidget {
  final double cwidth;
  const MiddleWidget({super.key, required this.cwidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      height: 235,
      width: cwidth,
      decoration: BoxDecoration(
        color: const Color(0xFF182232),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: "950",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: "GHC\n",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                TextSpan(
                  text: "MOMO today",
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendDot({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class MomoKpiWidget extends StatefulWidget {
  final double cwidth;

  const MomoKpiWidget({
    super.key,
    required this.cwidth,
  });

  @override
  State<MomoKpiWidget> createState() => _MomoKpiWidgetState();
}

class _MomoKpiWidgetState extends State<MomoKpiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _amountAnim;

  double _currentAmount = 0.0;
  double _previousAmount = 0.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _amountAnim = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  void _animateTo(double newValue) {
    if (!mounted) return;

    final oldValue = _currentAmount;

    _amountAnim = Tween<double>(
      begin: oldValue,
      end: newValue,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller
      ..reset()
      ..forward();

    _previousAmount = oldValue;
    _currentAmount = newValue;
  }
  double get difference => _currentAmount - _previousAmount;

  double get percentage {
    if (_previousAmount == 0) {
      return _currentAmount == 0 ? 0 : 100;
    }

    return (difference / _previousAmount) * 100;
  }

  bool get isIncrease => difference >= 0;

  Color get trendColor =>
      isIncrease ? Colors.greenAccent : Colors.redAccent;

  IconData get trendIcon =>
      isIncrease ? Icons.trending_up : Icons.trending_down;

  String get percentLabel =>
      "${isIncrease ? '+' : '-'}${percentage.abs().toStringAsFixed(1)}%";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardStats>(
      stream: context.read<Datafeed>().dashboardStatsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildCard();
        }

        if (!snapshot.hasData) {
          return _buildCard();
        }

        final stats = snapshot.data!;

        final momo = stats.companyMomo+stats.companydebtpay_momo;

        // Animate only when value changes
        if (momo != _currentAmount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && momo != _currentAmount) {
              _animateTo(momo);
              setState(() {});
            }
          });
        }

        return _buildCard();
      },
    );
  }

  Widget _buildCard() {
    return Container(
      width: widget.cwidth,
      height: 235,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF182232),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total MOMO",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.phone_android,
                    color: trendColor,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          AnimatedBuilder(
            animation: _amountAnim,
            builder: (context, child) {
              return FittedBox(
                child: Text(
                  "GHS ${NumberFormat('#,##0.00').format(_amountAnim.value)}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 6),

          const Text(
            "Total across branches",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white54,
            ),
          ),

          const Spacer(),

          // ======================================================
          // TREND
          // ======================================================

          Row(
            children: [
              Icon(
                trendIcon,
                color: trendColor,
                size: 15,
              ),

              const SizedBox(width: 4),

              Text(
                percentLabel,
                style: TextStyle(
                  color: trendColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(width: 6),

              const Text(
                "vs previous",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ======================================================
          // PROGRESS
          // ======================================================

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: min(
                percentage.abs() / 100,
                1,
              ),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                trendColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// class MomoKpiWidget extends StatefulWidget {
//   final double cwidth;
//   final double todayAmount;
//   final double yesterdayAmount;
//
//   const MomoKpiWidget({
//     super.key,
//     required this.cwidth,
//     required this.todayAmount,
//     required this.yesterdayAmount,
//   });
//
//   @override
//   State<MomoKpiWidget> createState() => _MomoKpiWidgetState();
// }
//
// class _MomoKpiWidgetState extends State<MomoKpiWidget>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _amountAnim;
//   String companyId = '';
//
//   @override
//   void initState() {
//     super.initState();
//
//
//
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1200),
//     );
//
//     _amountAnim = Tween<double>(
//       begin: 0,
//       end: widget.todayAmount,
//     ).animate(CurvedAnimation(
//       parent: _controller,
//       curve: Curves.easeOut,
//     ));
//
//     _controller.forward();
//     WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback((_) {
//       final datafeed = context.read<Datafeed>();
//       companyId = datafeed.companyid;
//
//       //();
//     });
//
//   }
//
//   double get difference => widget.todayAmount - widget.yesterdayAmount;
//
//   double get percentage =>
//       widget.yesterdayAmount == 0
//           ? 0
//           : (difference / widget.yesterdayAmount) * 100;
//
//   bool get isIncrease => difference >= 0;
//
//   Color get trendColor => isIncrease ? Colors.greenAccent : Colors.redAccent;
//
//   IconData get trendIcon =>
//       isIncrease ? Icons.trending_up : Icons.trending_down;
//
//   String get percentLabel =>
//       "${isIncrease ? '+' : '-'}${percentage.abs().toStringAsFixed(1)}%";
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: widget.cwidth,
//       height: 235,
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: const Color(0xFF182232),
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.15),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 "Total MOMO",
//                 style: TextStyle(
//                   color: Colors.white70,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               Container(
//                 decoration: BoxDecoration(
//                   color: trendColor.withOpacity(0.2),
//                   borderRadius: BorderRadius.all(Radius.circular(4))
//                 ),
//                   child: Padding(
//                     padding: const EdgeInsets.all(4.0),
//                     child: Icon(Icons.phone_android, color: trendColor, size: 16,),
//                   )
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 14),
//
//           AnimatedBuilder(
//             animation: _amountAnim,
//             builder: (context, child) {
//               return FittedBox(
//                 child: Text(
//                   "GHS ${_amountAnim.value.toStringAsFixed(2)}",
//                   style: const TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//               );
//             },
//           ),
//
//           const SizedBox(height: 6),
//
//           const Text(
//             "Today",
//             style: TextStyle(fontSize: 12, color: Colors.white54),
//           ),
//
//           const Spacer(),
//
//
//           Row(
//             children: [
//               Icon(trendIcon, color: trendColor, size: 18),
//               const SizedBox(width: 4),
//               Text(
//                 percentLabel,
//                 style: TextStyle(
//                   color: trendColor,
//                   fontSize: 13,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const SizedBox(width: 6),
//               const Text(
//                 "vs yesterday",
//                 style: TextStyle(fontSize: 11, color: Colors.white60),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 10),
//
//
//           ClipRRect(
//             borderRadius: BorderRadius.circular(6),
//             child: LinearProgressIndicator(
//               minHeight: 6,
//               value: min(percentage.abs() / 100, 1),
//               backgroundColor: Colors.white12,
//               valueColor: AlwaysStoppedAnimation(trendColor),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
// }

Widget _statCard({
  required String title,
  required String value,
  required String subtitle,
  required IconData icon,
  required Color iconColor,
}) {
  return Container(
    width: 200,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Color(0xFF182232),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + Icon
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70
              ),
            ),
            Icon(icon, color: iconColor, size: 20),
          ],
        ),

        const SizedBox(height: 4),

        // Value
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white
          ),
        ),

        const SizedBox(height: 4),

        // Subtitle
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
      ],
    ),
  );
}
