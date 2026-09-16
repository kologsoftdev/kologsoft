

import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/screens/role_access_config.dart';
import 'package:provider/provider.dart';

import '../models/account_type_model.dart';
import '../providers/routes.dart';
import 'account_type_reg.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({Key? key}) : super(key: key);

  ListTile _buildSubAccountTile(BuildContext context, String accountClass) {
    return ListTile(
      leading: const Icon(Icons.circle, color: Colors.white54, size: 10),
      title: Text(accountClass, style: const TextStyle(color: Colors.white70)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountTypeReg(
              account: AccountTypeModel(accountClass: accountClass),
            ),
          ),
        );
      },
    );
  }

  bool _isSalesUser(String accessLevel) {
    final normalized = accessLevel.toLowerCase().replaceAll(' ', '');
    return normalized.contains('sales');

  }

  bool _isCashier(String accessLevel) {
    final normalized = accessLevel.toLowerCase().replaceAll(' ', '');
    return normalized.contains('cashier');
  }

  bool _isWarehouseUser(String accessLevel) {
    final normalized = accessLevel.toLowerCase().replaceAll(' ', '');
    return normalized.contains('warehouse') || normalized.contains('stock officer');
  }

  bool _isAdminUser(String accessLevel) {
    final normalized = accessLevel.toLowerCase().replaceAll(' ', '');
    final adminRoles = ['admin', 'superadmin', 'manager'];
    return adminRoles.any((role) => normalized.contains(role));
  }

  bool _isSuperAdminUser(String accessLevel) {
    final normalized = accessLevel.toLowerCase().replaceAll(' ', '');
    return normalized.contains('superadmin');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final isSales = _isSalesUser(value.accesslevel);
        final isCashier = _isCashier(value.accesslevel);
        final isWarehouse = _isWarehouseUser(value.accesslevel);
        final isAdmin = _isAdminUser(value.accesslevel);
        final isSuperAdmin = _isSuperAdminUser(value.accesslevel);
        final isEnabled = value.hamperEnabled;
        // Navigate to sales page directly for sales users
        if (isSales) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamed(context, Routes.sales);
          });
          return const SizedBox.shrink();
        }

        if (isCashier) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamed(context, Routes.cashierPage);
          });
          return const SizedBox.shrink();
        }

        if (isWarehouse) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamed(context, Routes.warehousehomescreen);
          });
          return const SizedBox.shrink();
        }

        return Drawer(
          backgroundColor: const Color(0xFF0D1A26),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF0D1A26)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.factory, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      value.company.toString().toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Dashboard - Only for Admin and Super Admin
              if (isAdmin || isSuperAdmin)
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    unselectedWidgetColor: Colors.white,
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF1976D2),
                      onPrimary: Colors.white,
                      background: Color(0xFF0D1A26),
                      onBackground: Colors.white,
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.dashboard, color: Colors.white),
                    title: const Text(
                      'Dashboard',
                      style: TextStyle(color: Colors.white),
                    ),
                    selectedTileColor: const Color(0xFF1976D2),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              // Show User Management only for Admin
              if (isAdmin) ...[
                if(value.hasFeature('user_management'))
                ...[
                ExpansionTile(
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  leading: const Icon(Icons.people, color: Colors.white),
                  title: const Text(
                    'User Management',
                    style: TextStyle(color: Colors.white),
                  ),
                  children: [
                    if(value.hasFeature('register_staff'))
                    ListTile(
                      leading: const Icon(
                        Icons.person_add,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Register Staff',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.staffreg);
                      },
                    ),
                    if(value.hasFeature('view_staff'))
                    ListTile(
                      leading: const Icon(
                        Icons.people_outline,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'View Staff',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.staffView);
                      },
                    ),
                    if(value.hasFeature('role_access_config'))
                    ListTile(
                      leading: const Icon(
                        Icons.tune,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Role Access Config',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RoleAccessConfigScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                ],

                // System Setup
                if(value.companyid=='KS008')...[
                ExpansionTile(
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  leading: const Icon(Icons.manage_accounts, color: Colors.white),
                  title: const Text(
                    'Farmer Management',
                    style: TextStyle(color: Colors.white),
                  ),
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.person_add,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Farmer Registration',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.farmerreg);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.person_add,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'View Farmers',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.viewfarmers);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.grass,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Crop Registration',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.registercrop);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.language,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Register Language',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.registerlanguage);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.cast_for_education,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Education Level',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.educationlevel);
                      },
                    ),
                  ],
                ),

                const Divider(color: Colors.white24),
                ],
                if(value.companyid!='KS008')...[
                ExpansionTile(
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white,
                    leading: const Icon(Icons.manage_accounts, color: Colors.white),
                    title: const Text(
                      'Customer Management',
                      style: TextStyle(color: Colors.white),
                    ),
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.person_add,
                          color: Colors.white,
                        ),
                        title: const Text(
                          'Customer Registration',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, Routes.customerreg);
                        },
                      ),

                      // ListTile(
                      //   leading: const Icon(
                      //     Icons.person_add,
                      //     color: Colors.white,
                      //   ),
                      //   title: const Text(
                      //     'View Customers',
                      //     style: TextStyle(color: Colors.white),
                      //   ),
                      //   onTap: () {
                      //     Navigator.pushNamed(context, Routes.viewfarmers);
                      //   },
                      // ),
                    ],
                  ),
                const Divider(color: Colors.white24),
                ],
                if(value.hasFeature('item'))...[
                  ExpansionTile(
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white,
                    leading: const Icon(Icons.inventory, color: Colors.white),
                    title: const Text(
                      'Item',
                      style: TextStyle(color: Colors.white),
                    ),
                    children: [
                      if(value.hasFeature('item_category'))
                        ListTile(
                          leading: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Item Category',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.productcatereg);
                          },
                        ),
                      if(value.hasFeature('register_item'))
                        ListTile(
                          leading: const Icon(
                            Icons.add_business,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Register Item ',
                            style: TextStyle(color: Colors.white54),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.itemreg);
                          },
                        ),
                      if(value.hasFeature('view_item'))
                        ListTile(
                          leading: const Icon(
                            Icons.add_business,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'view',
                            style: TextStyle(color: Colors.white54),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.itemlist);
                          },
                        ),
                      if(value.hasFeature('branch_price'))
                        ListTile(
                          leading: const Icon(
                            Icons.add_business,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Branch Price',
                            style: TextStyle(color: Colors.white54),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.branchprice);
                          },
                        ),
                      if(value.hasFeature('print_barcode'))
                        ListTile(
                          leading: const Icon(
                            Icons.add_business,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Print Barcode',
                            style: TextStyle(color: Colors.white54),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.printbarcodes);
                          },
                        ),
                      if(value.hasFeature('bundle_item'))
                        ListTile(
                          leading: const Icon(
                            Icons.add_business,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Bundle Item',
                            style: TextStyle(color: Colors.white54),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.bundlesale);
                          },
                        ),
                      if(value.hasFeature('view_bundle'))
                        ListTile(
                          leading: const Icon(
                            Icons.add_business,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Bundle view',
                            style: TextStyle(color: Colors.white54),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.bundlesaleview);
                          },
                        ),
                      if(value.hasFeature('turn_off_bundle'))
                        ListTile(
                          leading: Icon(
                            Icons.card_giftcard,
                            color: isEnabled ? Colors.white : Colors.white24,
                          ),
                          title: Text(
                            'Turn off Bundle',
                            style: TextStyle(
                              color: isEnabled ? Colors.white54 : Colors.white24,
                            ),
                          ),
                          trailing: Switch(
                            value: isEnabled,
                            activeColor: Colors.greenAccent,
                            inactiveThumbColor: Colors.white24,
                            inactiveTrackColor: Colors.white10,
                            onChanged: (val) =>
                                context.read<Datafeed>().toggleHamper(val),
                          ),
                          onTap: () =>
                              context.read<Datafeed>().toggleHamper(!isEnabled),
                        ),
                      if(value.hasFeature('item_balance_sync'))
                        ListTile(
                          leading: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Item balance Sync',
                            style: TextStyle(color: Colors.white54),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.stockbalancesync);
                          },
                        ),
                      if(value.hasFeature('synczero'))
                        ListTile(
                          leading: const Icon(
                            Icons.sync,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Sync Item to Zero',
                            style: TextStyle(color: Colors.white54),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.synczero);
                          },
                        ),

                    ],
                  ),
                  const Divider(color: Colors.white24),
                ],

                // Stock Management
                if(value.hasFeature('stock_management'))...[
                  ExpansionTile(
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  leading: const Icon(Icons.inventory, color: Colors.white),
                  title: const Text(
                    'Stock Management',
                    style: TextStyle(color: Colors.white),
                  ),
                  children: [
                    if(value.hasFeature('new_stock_entry'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'New Stock Entry ',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.newstock);
                      },
                    ),
                    if(value.hasFeature('view_stock_entries'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'View Stock Entries ',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.stocklisttable);
                      },
                    ),
                    // if(value.hasFeature('view_stock'))
                    // ListTile(
                    //   leading: const Icon(
                    //     Icons.add_business,
                    //     color: Colors.white,
                    //   ),
                    //   title: const Text(
                    //     'View Stock ',
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    //   onTap: () {
                    //     Navigator.pushNamed(context, Routes.stocklist);
                    //   },
                    // ),
                    if(value.hasFeature('view_transfers'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Transfers',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.transfers);
                      },
                    ),
                    if(value.hasFeature('view_transfer_list'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Transfer List',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.transferlist);
                      },
                    ),
                    if(value.hasFeature('view_stock_transfers'))
                    // ListTile(
                    //   leading: const Icon(
                    //     Icons.add_business,
                    //     color: Colors.white,
                    //   ),
                    //   title: const Text(
                    //     'View Transfer List',
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    //   onTap: () {
                    //     Navigator.pushNamed(context, Routes.stocktransferlist);
                    //   },
                    // ),
                    ListTile(
                      leading: const Icon(
                        Icons.security_update_good_sharp,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Stock Adjustment',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.stocktake);
                      },
                    ),

                    // ListTile(
                    //   leading: const Icon(
                    //     Icons.add_business,
                    //     color: Colors.white,
                    //   ),
                    //   title: const Text(
                    //     'Requests',
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    //   onTap: () {
                    //     Navigator.pushNamed(context, Routes.stockrequest);
                    //   },
                    // ),
                    // ListTile(
                    //   leading: const Icon(
                    //     Icons.add_business,
                    //     color: Colors.white,
                    //   ),
                    //   title: const Text(
                    //     'Requests List',
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    //   onTap: () {
                    //     Navigator.pushNamed(context, Routes.stockrequestlist);
                    //   },
                    // ),
                    // ListTile(
                    //   leading: const Icon(
                    //     Icons.add_business,
                    //     color: Colors.white,
                    //   ),
                    //   title: const Text(
                    //     'Receive Stock',
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    //   onTap: () {
                    //     Navigator.pushNamed(context, Routes.receivestock);
                    //   },
                    // ),
                    // ListTile(
                    //   leading: const Icon(
                    //     Icons.add_business,
                    //     color: Colors.white,
                    //   ),
                    //   title: const Text(
                    //     'Supply',
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    //   onTap: () {
                    //     Navigator.pushNamed(context, Routes.stocksupply);
                    //   },
                    // ),
                   if(value.hasFeature('purchase_returns'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Purchase returns',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.purchaseReturns);
                      },
                    ),
                    if(value.hasFeature('view_purchase_returns'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'View Purchase returns',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.purchaseReturnsView);
                      },
                    ),
                    if(value.hasFeature('warehouse_supply'))
                    ListTile(
                      leading: const Icon(
                        Icons.warehouse_outlined,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Warehouse Supply',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.warehousehomescreen);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.report,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Supply Report',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.warehousesupplyreport);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Transaction Supply Report',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.transactionsupplyreport);
                      },
                    ),
                    if(value.hasFeature('deleted_stock'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Deleted stock',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.deletedstock);
                      },
                    ),
                    // ListTile(
                    //   leading: const Icon(
                    //     Icons.upload_file,
                    //     color: Colors.white,
                    //   ),
                    //   title: const Text(
                    //     'Upload stock',
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    //   onTap: () {
                    //     Navigator.pushNamed(context, Routes.uploadstock);
                    //   },
                    // ),
                    ListTile(
                      leading: const Icon(
                        Icons.transfer_within_a_station,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Upload stock transfers',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.uploadstocktransfer);
                      },
                    ),

                  ],
                ),
                  const Divider(color: Colors.white24),
                ],


                // Transactions
                if(value.hasFeature('transactions'))...[
                ExpansionTile(
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  leading: const Icon(Icons.shopping_cart, color: Colors.white),
                  title: const Text(
                    'Transactions',
                    style: TextStyle(color: Colors.white),
                  ),
                  children: [
                    if(value.hasFeature('sales'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Sales ',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.sales);
                      },
                    ),
                  if(value.hasFeature('cashier'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Cashier ',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.cashierPage);
                      },
                    ),
                    if(value.hasFeature('sales_view'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Sales view',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.salesview);
                      },
                    ),
                    if(value.hasFeature('close_sale'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Close Sale',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.closesale);
                      },
                    ),
                    if(value.hasFeature('discount'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Discount',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.discountmanager);
                      },
                    ),
                    if(value.hasFeature('discount_view'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Discount view',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.discountmanagerview);
                      },
                    ),

                  ],
                ),
                  const Divider(color: Colors.white24),
                ],

                if(value.hasFeature('account'))...[
                  ExpansionTile(
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white,
                    leading: const Icon(
                      Icons.account_balance,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Account',
                      style: TextStyle(color: Colors.white),
                    ),
                    children: [
                      if(value.hasFeature('chart_of_accounts'))
                        ListTile(
                          leading: const Icon(
                            Icons.account_tree,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Chart of Accounts',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.coa);
                          },
                        ),
                      if(value.hasFeature('activity_chart'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Activity Chart',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.activityChartReg);
                          },
                        ),
                      if(value.hasFeature('payment_accounts'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Payment Accounts',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.paymentaccounts);
                          },
                        ),
                      if(value.hasFeature('payment_duration'))
                        ListTile(
                          leading: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Payment Duration',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.paymentdurationreg);
                          },
                        ),
                      if(value.hasFeature('configure_vat'))
                        ListTile(
                          leading: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Configure Vat',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.configurevat);
                          },
                        ),
                      if(value.hasFeature('add_vat'))
                        ListTile(
                          leading: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Add Vat',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.addvat);
                          },
                        ),
                      if(value.hasFeature('creditor_openbal'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Creditors Open Balance',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.creditopenbal);
                          },
                        ),
                      if(value.hasFeature('creditor_openbalview'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'View Creditors Balance',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.creditopenbalview);
                          },
                        ),
                      if(value.hasFeature('creditor_payable'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Account Payable',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.creditorpayable);
                          },
                        ),
                      if(value.hasFeature('view_account_payable'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'View Account Payable',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.creditorpayableview);
                          },
                        ),
                      if(value.hasFeature('receivables'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Receivables',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.debtorlist);
                          },
                        ),
                      if(value.hasFeature('receivables'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Receive Payments',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.receivepayments);
                          },
                        ),
                      if(value.hasFeature('view_receivables'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'View Receivables',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.debtpayments);
                          },
                        ),
                      if(value.hasFeature('debtor_bal'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Debtors Balance',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.debtorBal);
                          },
                        ),
                      if(value.hasFeature('bank_transfer'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Bank transfer',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.banktransfer);
                          },
                        ),
                      if(value.hasFeature('banktransferview'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Bank transfer view',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.banktransferview);
                          },
                        ),
                      if(value.hasFeature('journal_entry'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Journal',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.journalEntry);
                          },
                        ),
                      if(value.hasFeature('journal_view'))
                        ListTile(
                          leading: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'View Journal',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.journalView);
                          },
                        ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                ],

                if(value.hasFeature('expenses'))...[
                  ExpansionTile(
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white,
                    leading: const Icon(Icons.shopping_cart, color: Colors.white),
                    title: const Text(
                      'Expenses',
                      style: TextStyle(color: Colors.white),
                    ),
                    children: [
                      if(value.hasFeature('entry_expense'))
                        ListTile(
                          leading: const Icon(
                            Icons.add_business,
                            color: Colors.white54,
                          ),
                          title: const Text(
                            'Expense Entry ',
                            style: TextStyle(color: Colors.white54),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.expense);
                          },
                        ),
                      if(value.hasFeature('view_expense'))
                        ListTile(
                          leading: const Icon(
                            Icons.add_business,
                            color: Colors.white54,
                          ),
                          title: const Text(
                            'View Expenses',
                            style: TextStyle(color: Colors.white54),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.expenseview);
                          },
                        ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                ],

                if(value.hasFeature('reports'))...[
                ExpansionTile(
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  leading: const Icon(Icons.bar_chart, color: Colors.white),
                  title: const Text(
                    'Reports',
                    style: TextStyle(color: Colors.white),
                  ),
                  children: [
                    if(value.hasFeature('stock_report'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Stock Report',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.stockreport);
                      },
                    ),
                    // if(value.hasFeature('sales_report_summary'))
                    // ListTile(
                    //   leading: const Icon(
                    //     Icons.add_business,
                    //     color: Colors.white54,
                    //   ),
                    //   title: const Text(
                    //     'Sales Report Summary',
                    //     style: TextStyle(color: Colors.white54),
                    //   ),
                    //   onTap: () {
                    //     Navigator.pushNamed(context, Routes.salesreportsummary);
                    //   },
                    // ),
                    if(value.hasFeature('sales_report'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Sales Report',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.salesreport);
                      },
                    ),
                    if(value.hasFeature('sales_register'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Sales Register',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.salesregister);
                      },
                    ),
                    if(value.hasFeature('general_ledger'))
                    ListTile(
                      leading: const Icon(
                        Icons.account_balance,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'General Ledger',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: (){
                        Navigator.pushNamed(context, Routes.generalledger);
                      },
                    ),
                    if(value.hasFeature('profit_and_loss'))
                    ListTile(
                      leading: const Icon(
                        Icons.trending_up,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Profit and Loss',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.profitAndLoss);
                      },
                    ),
                    if(value.hasFeature('category_sales_report'))
                    ListTile(
                      leading: const Icon(
                        Icons.account_balance,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Category Sales report',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: (){
                        Navigator.pushNamed(context, Routes.categorysalereport);
                      },
                    ),
                    if(value.hasFeature('sales_invoice'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Sales Invoice',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.salesinvoice);
                      },
                    ),
                    if(value.hasFeature('hamper_sales_report'))
                    ListTile(
                      leading: const Icon(
                        Icons.account_balance,
                        color: Colors.white54,
                      ),
                      title: const Text(
                        'Hamper Sales report',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: (){
                        Navigator.pushNamed(context, Routes.hampersalereport);
                      },
                    ),
                    if(value.hasFeature('branch_balance'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Branch Balance',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.branchbalance);
                      },
                    ),
                    if(value.hasFeature('supplier_report'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Supplier Report',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.supplierreport);
                      },
                    ),
                    if(value.hasFeature('payment_report'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Payment Report',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.paymentreport);
                      },
                    ),
                    if(value.hasFeature('momo_report'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'MOMO Report',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.momoreport);
                      },
                    ),
                    if(value.hasFeature('damage_report'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Damage Report',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.damagereport);
                      },
                    ),
                    if(value.hasFeature('debtor_report'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Debtor Report',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.debtorreport);
                      },
                    ),
                    if(value.hasFeature('reorder_stock_report'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Reorder Stock Report',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.reorderStock);
                      },
                    ),
                    if(value.hasFeature('finished_stock_report'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Finished Stock Report',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.finishedstock);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.report,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Stock value Report',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.stockvaluepage);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Supply Report',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.transactionsupplyreport);
                      },
                    ),
                  ],
                ),
                  const Divider(color: Colors.white24),
                ],

                // Damages & Sales Returns
                if(value.hasFeature('damages'))...[
                ExpansionTile(
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  leading: const Icon(Icons.warning, color: Colors.white),
                  title: const Text(
                    'Damages',
                    style: TextStyle(color: Colors.white),
                  ),
                  children: [
                    if(value.hasFeature('register_damage'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Register Damage',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.damages);
                      },
                    ),
                    if(value.hasFeature('damagelist'))
                    ListTile(
                      leading: const Icon(
                        Icons.add_business,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Damages list',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.damagelist);
                      },
                    ),

                  ],
                ),
                 const Divider(color: Colors.white24),
                ],

                if(value.hasFeature('sales_return'))...[
                ExpansionTile(
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  leading: const Icon(Icons.business, color: Colors.white),
                  title: const Text(
                    'Sales Return',
                    style: TextStyle(color: Colors.white),
                  ),
                  children: [
                    if(value.hasFeature('return_sales'))
                    ListTile(
                      leading: const Icon(Icons.list_alt, color: Colors.white54),
                      title: const Text(
                        'Return Sales',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.salesreturn);
                      },
                    ),
                    if(value.hasFeature('sales_return_view'))
                    ListTile(
                      leading: const Icon(Icons.list, color: Colors.white),
                      title: const Text(
                        'View Sales return',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.salesreturnlist);
                      },
                    ),

                  ],
                ),
                  const Divider(color: Colors.white24),
                ],

                if(value.hasFeature('uploads'))...[
                ExpansionTile(
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  leading: const Icon(Icons.upload_file, color: Colors.white),
                  title: const Text(
                    'Uploads',
                    style: TextStyle(color: Colors.white),
                  ),
                  children: [
                    if(value.hasFeature('receipt_upload'))
                    ListTile(
                      leading: const Icon(Icons.receipt_long, color: Colors.white54),
                      title: const Text(
                        'Receipt',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.uploadreceipt);
                      },
                    ),
                   if(value.hasFeature('receipt_upload_view'))
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined, color: Colors.white54),
                      title: const Text(
                        'Receipt view',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.uploadreceiptview);
                      },
                    ),
                   if(value.hasFeature('upload_item'))
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined, color: Colors.white),
                      title: const Text(
                        'Upload Item',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.uploaditem);
                      },
                    ),
                    if(value.hasFeature('salesupload'))
                      ListTile(
                        leading: const Icon(Icons.point_of_sale, color: Colors.white),
                        title: const Text(
                          'Sales Upload',
                          style: TextStyle(color: Colors.white54),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, Routes.salesupload);
                        },
                      ),

                  ],
                ),
                 const Divider(color: Colors.white24),
                ],

                if(value.hasFeature('system_setup'))
                  ...[
                    ExpansionTile(
                      iconColor: Colors.white,
                      collapsedIconColor: Colors.white,
                      leading: const Icon(Icons.settings, color: Colors.white),
                      title: const Text(
                        'System Setup',
                        style: TextStyle(color: Colors.white),
                      ),
                      children: [
                        if(value.hasFeature('supplier_registration'))
                          ListTile(
                            leading: const Icon(
                              Icons.person_add,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Supplier Registration',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pushNamed(context, Routes.supplierreg);
                            },
                          ),
                        if(value.hasFeature('branch_registration'))
                          ListTile(
                            leading: const Icon(
                              Icons.person_add,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Branch Registration',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pushNamed(context, Routes.branchreg);
                            },
                          ),
                        if(value.hasFeature('return_damage_reasons'))
                          ListTile(
                            leading: const Icon(
                              Icons.add_business,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Return/Damage reasons',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pushNamed(context, Routes.returnreasons);
                            },
                          ),
                        if(value.hasFeature('stocking_mode'))
                          ListTile(
                            leading: const Icon(
                              Icons.add_business,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Stocking Mode ',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pushNamed(context, Routes.stockingmode);
                            },
                          ),
                        if(value.hasFeature('add_community'))
                          ListTile(
                            leading: const Icon(
                              Icons.add,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Add Community',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pushNamed(context, Routes.registercommunity);
                            },
                          ),
                        if(value.hasFeature('sms_setup'))
                          ListTile(
                            leading: const Icon(
                              Icons.sms,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'SMS Setup',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pushNamed(context, Routes.SmsConfiguration);
                            },
                          ),
                        ListTile(
                          leading: const Icon(
                            Icons.data_exploration,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'collection Manager',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.collectionmanager);
                          },
                        ),
                        // ListTile(
                        //   leading: const Icon(
                        //     Icons.graphic_eq,
                        //     color: Colors.white,
                        //   ),
                        //   title: const Text(
                        //     'Usage Stats',
                        //     style: TextStyle(color: Colors.white),
                        //   ),
                        //   onTap: () {
                        //     Navigator.pushNamed(context, Routes.firebasestats);
                        //   },
                        // ),

                      ],
                    ),
                    const Divider(color: Colors.white24),
                  ],

                //SMS Management
                if(value.hasFeature('sms-management'))...[
                ListTile(
                  leading: const Icon(Icons.sms, color: Colors.white),
                  title: const Text(
                    'SMS Management',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, Routes.smsManagement);
                  },
                ),
                const Divider(color: Colors.white24),
                ],

                ListTile(
                  leading: const Icon(Icons.login, color: Colors.white),
                  title: const Text(
                    'logout',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    await value.logout(context);
                    // Navigator.pushNamed(context, Routes.homedashboard);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

