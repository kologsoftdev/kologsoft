
import 'package:kologsoft/screens/account_type_view.dart';
import 'package:kologsoft/screens/activity_chart_reg.dart';
import 'package:kologsoft/screens/activity_chart_view.dart';
import 'package:kologsoft/screens/branch_reg.dart';
import 'package:kologsoft/screens/cashier_desk.dart';

import 'package:kologsoft/screens/damages.dart';
import 'package:kologsoft/screens/debtors_bal_view.dart';
import 'package:kologsoft/screens/debtors_balance.dart';
import 'package:kologsoft/screens/expense_entry.dart';
import 'package:kologsoft/screens/expense_entry_view.dart';
import 'package:kologsoft/screens/journal_entries.dart';
import 'package:kologsoft/screens/journal_entry_view.dart';
import 'package:kologsoft/screens/login_screen.dart';
import 'package:kologsoft/screens/newstock.dart';
import 'package:kologsoft/screens/payment_capabilities.dart';
import 'package:kologsoft/screens/payment_duration_reg.dart';
import 'package:kologsoft/screens/payment_duration_view.dart';
import 'package:kologsoft/screens/payment_methods.dart';
import 'package:kologsoft/screens/product_category_reg.dart';
import 'package:kologsoft/screens/productcategory_view.dart';
import 'package:kologsoft/screens/sales_page.dart';
import 'package:kologsoft/screens/staff_profile.dart';
import 'package:kologsoft/providers/route_guard.dart';
import 'package:kologsoft/screens/staff_view.dart';
import 'package:kologsoft/screens/sub_account_form.dart';
import 'package:kologsoft/screens/sub_account_form_view.dart';
import 'package:kologsoft/screens/transfer_page.dart';
import 'package:kologsoft/screens/transfers.dart';
import 'package:kologsoft/screens/sms_management.dart';

import '../screens/Creditorpayable.dart';
import '../screens/Creditorpayablelist.dart';
import '../screens/StockBalanceSync.dart';
import '../screens/account_type_reg.dart';
import '../screens/add_community.dart';
import '../screens/addtaxvat.dart';
import '../screens/addtaxvatview.dart';
import '../screens/banktransfer.dart';
import '../screens/banktransferview.dart';
import '../screens/branch_view.dart';
import '../screens/branchbalancereport.dart';
import '../screens/branchprice.dart';
import '../screens/bundlesale.dart';
import '../screens/bundlesaleview.dart';
import '../screens/cashier_page.dart';
import '../screens/categorysalereport.dart';
import '../screens/closesales.dart';
import '../screens/collectionManager.dart';
import '../screens/companylist.dart';
import '../screens/companyreg.dart';
import '../screens/configurevat.dart';
import '../screens/configurevatview.dart';
import '../screens/creditopenbalance.dart';
import '../screens/creditopenbalancelist.dart';
import '../screens/crop_registration.dart';
import '../screens/customer_registration.dart';

import '../screens/damagereport.dart';
import '../screens/damagesslist.dart';
import '../screens/ViewReceivables.dart';
import '../screens/Receivables.dart';
import '../screens/debtorreport.dart';
import '../screens/deletedstock.dart';
import '../screens/discounmangerpage.dart';
import '../screens/discountmangerpagview.dart';
import '../screens/farmer_reg.dart';
import '../screens/finishedstockreport.dart';
import '../screens/generalledger.dart';
import '../screens/hamperreport.dart';
import '../screens/home_dashboard.dart';

import '../screens/itemlist.dart';
import '../screens/itemreg.dart';
import '../screens/journal_entry_view.dart';
import '../screens/languageregistration.dart';
import '../screens/momoreport.dart';
import '../screens/printbarcodes.dart';
import '../screens/profit_and_loss.dart';
import '../screens/purchase_returns.dart';
import '../screens/receivpayments.dart';
import '../screens/reorderstockreport.dart';
import '../screens/role_access_dashboard.dart';
import '../screens/purchasereturns_view.dart';
import '../screens/receivestock.dart';
import '../screens/registereducationlevel.dart';
import '../screens/return_reasons.dart';
import '../screens/salereportssummary.dart';
import '../screens/sales_upload_page.dart';
import '../screens/salesinvoice.dart';
import '../screens/salesregisterreport.dart';
import '../screens/salesreport.dart';
import '../screens/salesreturn.dart';
import '../screens/salesreturnlist.dart';
import '../screens/salesview.dart';
import '../screens/smsconfig.dart';
import '../screens/payment_report.dart';
import '../screens/staff.dart';
import '../screens/stock_report.dart';
import '../screens/stockcostanalysis.dart';
import '../screens/stocking_mode.dart';
import '../screens/stocklist.dart';
import '../screens/stocklist_table.dart';
import '../screens/stockrequest.dart';
import '../screens/stockrequestlist.dart';
import '../screens/stocksupply.dart';
import '../screens/stocktake.dart';
import '../screens/stockvaluepage.dart';
import '../screens/supplierlist.dart';
import '../screens/supplierreport.dart';
import '../screens/supplierscreen.dart';
import '../screens/synitemnotinstockreport.dart';
import '../screens/systemAdminpage.dart';
import '../screens/transferlisttable.dart';
import '../screens/uploaditem.dart';
import '../screens/uploadreceipt.dart';
import '../screens/uploadreceiptview.dart';
import '../screens/uploadstock.dart';
import '../screens/uploadtransfer.dart';
import '../screens/viewfarmers.dart';
import '../screens/warehousehomescreen.dart';
import '../screens/warehousereg.dart';
import 'package:provider/provider.dart';
import '../screens/warehousesupplyreport.dart';
import '../screens/transactionsupplyreport.dart';
import 'Datafeed.dart';

class Routes {
  static const String home = '/home';
  static const String login = '/login';
  static const String adduser = '/adduser';
  static const String branchreg = '/branchreg';
  static const String supplierreg = '/supplierreg';
  static const String stockingmode = '/stockingmode';
  static const String supplierlist = '/supplierlist';
  static const String warehousereg = '/warehousereg';
  static const String warehouselist = '/warehouselist';
  static const String companyreg = '/companyreg';
  static const String companylist = '/companylist';
  static const String itemreg = '/itemreg';
  static const String itemlist = '/itemlist';
  static const String branchview = '/branchview';
  static const String customerreg = '/customerreg';
  static const String productcatereg = '/productcatereg';
  static const String productcateview = '/productcateview';
  static const String paymentdurationreg = '/paymentdurationreg';
  static const String paymentdurationview = '/paymentdurationview';
  static const String newstock = '/newstock';
  static const String staffreg = '/staffreg';
  static const String staffView = '/staffView';
  static const String staffprofile = '/staffprofile';
  static const String sales = '/sales';
  static const String transfers = '/transfers';
  static const String transferlist = '/transferlist';
  static const String stocklist = '/stocklist';
  static const String branchprice = '/branchprice';
  static const String stockrequest = '/stockrequest';
  static const String stockrequestlist = '/stockrequestlist';
  static const String activityChartReg = '/activityChartReg';
  static const String subAccountForm = '/subAccountForm';
  static const String coa = '/coa';
  static const String stocksupply = '/stocksupply';
  static const String paymentaccounts = '/paymentaccounts';
  static const String accountTypeView = '/accountTypeView';
  static const String activityChartView = '/activityChartView';
  static const String subAccountView = '/subAccountView';
  static const String damages = '/damages';
  static const String receivestock = '/receivestock';
  static const String salesreturn = '/salesreturn';
  static const String expense = '/expense';
  static const String expenseview = '/expenseview';
  static const String paymentMethod = '/paymentMethod';
  static const String salesreturnlist = '/salesreturnlist';
  static const String damagelist = '/damagelist';
  static const String cashier = '/cashier';
  static const String cashierPage = '/cashierPage';
  static const String purchaseReturns = '/purchaseReturns';
  static const String purchaseReturnsView = '/purchaseReturnsView';
  static const String salesview = '/salesview';
  static const String salesinvoice = '/salesinvoice';
  static const String salesreport = '/salesreport';
  static const String salesreportsummary = '/salesreportsummary';
  static const String paymentreport = '/paymentreport';
  static const String salesregister = '/salesregister';
  static const String stockreport = '/stockreport';
  static const String configurevat = '/configurevat';
  static const String configurevatview = '/configurevatview';
  static const String addvat = '/addvat';
  static const String addvatview = '/addvatview';
  static const String printbarcodes = '/printbarcodes';
  static const String bundlesale = '/bundlesale';
  static const String bundlesaleview = '/bundlesaleview';
  static const String uploadreceipt = '/uploadreceipt';
  static const String uploadreceiptview = '/uploadreceiptview';
  static const String uploaditem = '/uploaditem';
  static const String closesale = '/closesale';
  static const String creditopenbal = '/creditopenbal';
  static const String creditopenbalview = '/creditopenbalview';
  static const String creditorpayable = '/creditorpayable';
  static const String creditorpayableview = '/creditorpayableview';
  static const String debtorlist = '/debtorlist';
  static const String debtpayments = '/debtpayments';
  static const String debtorBal = '/debtorBal';
  static const String creditorBal = '/creditorBal';
  static const String debtorBalView = '/debtorBalView';
  static const String creditorBalView = '/creditorBalView';
  static const String banktransfer = '/banktransfer';
  static const String banktransferview = '/banktransferview';
  static const String journalEntry = '/journalEntry';
  static const String journalView = '/journalView';
  static const String returnreasons = '/returnreasons';
  static const String discountmanager = '/discountmanager';
  static const String discountmanagerview = '/discountmanagerview';
  static const String farmerreg = '/farmerreg';
  static const String registercrop = '/registercrop';
  static const String registerlanguage = '/registerlanguage';
  static const String educationlevel = '/educationlevel';
  static const String branchbalance = '/branchbalance';
  static const String registercommunity = '/registercommunity';
  static const String generalledger = '/generalledger';
  static const String profitAndLoss = '/profitandloss';
  static const String categorysalereport = '/categorysalereport';
  static const String hampersalereport = '/hampersalereport';
  static const String stocklisttable = '/stocklisttable';
  static const String viewfarmers = '/viewfarmers';
  static const String stockbalancesync = '/stockbalancesync';
  static const String smsManagement = '/smsManagement';
  static const String SmsConfiguration = '/SmsConfiguration';
  static const String staffsalereport = '/staffsalereport';
  static const String roleAccessDashboard = '/roleAccessDashboard';
  static const String supplierreport = '/supplierreport';
  static const String stocktransferlist = '/stocktransferlist';
  static const String deletedstock = '/deletedstock';
  static const String momoreport = '/momoreport';
  static const String damagereport = '/damagereport';
  static const String debtorreport = '/debtorreport';
  static const String systemadmin ='/systemadmin';
  static const String finishedstock ='/finishedstock';
  static const String reorderStock ='/reorderStock';
  static const String warehousehomescreen ='/warehousehomescreen';
  static const String collectionmanager ='/collectionmanager';
  static const String salesupload ='/salesupload';
  static const String salesunovalidate ='/salesunovalidate';
  static const String synczero ='/synczero';
  static const String updatecostp ='/updatecostp';
  static const String uploadstock ='/uploadstock';
  static const String uploadstocktransfer ='/uploadstocktransfer';
  static const String warehousesupplyreport ='/warehousesupplyreport';
  static const String transactionsupplyreport = '/transactionsupplyreport';
  static const String stockvaluepage = '/stockvaluepage';
  static const String receivepayments = '/receivepayments';
  static const String stocktake = '/stocktake';
  static const String dailysalesreport = '/dailysalesreport';
}

final pages = {
  Routes.login: (context) => const LoginScreen(),
  Routes.home: (context) => const RouteGuard(child: HomeDashboard()),
  Routes.roleAccessDashboard: (context) => const RouteGuard(child: RoleAccessDashboard()),
  Routes.branchreg: (context) => const RouteGuard(child: BranchRegistration()),
  Routes.supplierreg: (context) => const RouteGuard(child: SupplierRegistration()),
  Routes.stockingmode: (context) => const RouteGuard(child: StockingMode()),
  Routes.supplierlist: (context) => const RouteGuard(child: SupplierListPage()),
  Routes.companyreg: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin','systemadmin'], child: CompanyRegPage()),
  Routes.companylist: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin','systemadmin'], child: CompanyListPage()),
  Routes.warehousereg: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: WarehouseRegistration()),
  Routes.itemreg: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant', 'warehouse','systemadmin'], child: ItemRegPage()),
  Routes.itemlist: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant', 'warehouse','systemadmin'], child: ItemListPage()),
  Routes.branchview: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: BranchView()),
  Routes.customerreg: (context) => RouteGuard(allowedAccessLevels: ['sales', 'sales attendance', 'sales manager', 'admin', 'super admin', 'operations officers','systemadmin'], child: CustomerRegistration()),
  Routes.productcatereg: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: ProductCategoryReg()),
  Routes.productcateview: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: ProductCategoryView()),
  Routes.paymentdurationreg: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: PaymentDurationReg()),
  Routes.paymentdurationview: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: PaymentDurationView()),
  Routes.newstock: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: NewStock()),
  Routes.staffreg: (context) => RouteGuard(allowedAccessLevels: ['admin','super admin','systemadmin'], child: Staff()),
  Routes.staffprofile: (context) => const RouteGuard(child: StaffProfile()),
  Routes.sales: (context) => const RouteGuard(allowedAccessLevels: ['sales', 'sales attendance', 'sales manager', 'admin', 'super admin', 'operations officers','systemadmin'], child: SalesPage()),
  Routes.transfers: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: NewTransfer()),
  Routes.transferlist: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: StockTransferDetails()),
  Routes.stocklist: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: StockListPage()),
  Routes.staffView: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers','systemadmin'], child: StaffView()),
  Routes.branchprice: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: BranchPricePage()),
  Routes.stockrequest: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'sales manager','systemadmin'], child: StockRequest()),
  Routes.stockrequestlist: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'sales manager','systemadmin'], child: StockRequestDetails()),
  Routes.activityChartReg: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: ActivityChartReg()),
  Routes.subAccountForm: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: SubAccountForm()),
  Routes.coa: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: AccountTypeReg()),
  Routes.stocksupply: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: StockSupply()),
  Routes.paymentaccounts: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: PaymentMethodsListScreen()),
  Routes.accountTypeView: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: AccountTypeView()),
  Routes.activityChartView: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: ActivityChartView()),
  Routes.subAccountView: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: SubAccountFormView()),
  Routes.damages: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: Damages()),
  Routes.receivestock: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: StockReceiving()),
  Routes.salesreturn: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'sales', 'sales attendance', 'sales manager','systemadmin'], child: Salesreturn()),
  Routes.expense: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: ExpenseEntry()),
  Routes.expenseview: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: ExpenseEntryView()),
  Routes.paymentMethod: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: PaymentMethods()),
  Routes.salesreturnlist: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: SalesreturnListPage()),
  Routes.damagelist: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: DamagesListPage()),
  Routes.cashier: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'sales', 'sales attendance', 'sales manager', 'cashier','systemadmin'], child: ReceiptDashboardScreen()),
  Routes.purchaseReturns: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: PurchaseReturn()),
  Routes.purchaseReturnsView: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: PurchaseReturnTableScreen()),
  Routes.cashierPage: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'sales', 'sales attendance', 'sales manager', 'cashier','systemadmin'], child: CashierPage()),
  Routes.salesview: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'sales','operations officers', 'sales attendance', 'sales manager','systemadmin'], child: SalesViewPage()),
  Routes.salesinvoice: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'sales', 'sales attendance', 'sales manager','systemadmin'], child: SalesInvoice()),
  Routes.salesreport: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant', 'sales manager','systemadmin'], child: SalesReport()),
  Routes.salesreportsummary: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant', 'sales manager','systemadmin'], child: SalesSummaryPage()),
  Routes.paymentreport: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant', 'sales manager','systemadmin'], child: PaymentReportPage()),
  Routes.salesregister: (context) => const RouteGuard(allowedAccessLevels: ['sales', 'sales attendance', 'sales manager', 'admin', 'super admin', 'operations officers','systemadmin'], child: SalesRegister()),
  Routes.staffsalereport: (context) => const RouteGuard(allowedAccessLevels: ['sales', 'sales attendance', 'sales manager', 'admin', 'super admin', 'operations officers','systemadmin'], child: SalesRegister()),
  Routes.stockreport: (context) => const RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant', 'sales manager', 'sales attendance','systemadmin'], child: StockReportPage()),
  Routes.configurevat: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: ConfigureVatreg()),
  Routes.configurevatview: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: ConfigurevatView()),
  Routes.addvat: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: addTaxVat()),
  Routes.addvatview: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: AddTaxVatvatView()),
  Routes.printbarcodes: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: PrintBarcodes()),
  Routes.bundlesale: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'sales', 'sales attendance', 'sales manager','systemadmin'], child: BundlePage()),
  Routes.bundlesaleview: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'sales', 'sales attendance', 'sales manager','systemadmin'], child: bundleSaleViewPage()),
  Routes.uploadreceipt: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: ReceiptUploadPage()),
  Routes.uploadreceiptview: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: uploadReceiptViewPage()),
 // Routes.uploaditem: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: ItemUploadPage()),
  Routes.closesale: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'cashier', 'sales manager','systemadmin'], child: CloseSalesPage ()),
  Routes.creditopenbal: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: creditOpenBalScreen ()),
  Routes.creditopenbalview: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: creditOpenBalViewPage ()),
  Routes.creditorpayable: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: CreditorPayableScreen ()),
  Routes.creditorpayableview: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: CreditorPayablelistScreen ()),
  Routes.debtorlist: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: ReceivablesListPage ()),
  Routes.debtpayments: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: ViewReceivables ()),
    Routes.debtorBal: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: DebtorsBalance ()),
  Routes.debtorBalView: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: DebtorsBalView ()),
  Routes.banktransfer: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: Banktransfer ()),
  Routes.banktransferview: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: BanktransferView()),
  Routes.journalEntry: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: JournalEntries()),
  Routes.returnreasons: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: ReturnReasons()),
  Routes.discountmanager: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: DiscountCodeRegisterPage()),
  Routes.discountmanagerview: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: DiscountCodeListPage()),
  Routes.farmerreg: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'sales attendance', 'sales manager','systemadmin'], child: FarmerRegistration()),
  Routes.registercrop: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers','systemadmin'], child: CropRegistration()),
  Routes.registerlanguage: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers','systemadmin'], child: LanguageRegistration()),
  Routes.educationlevel: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers','systemadmin'], child: EducationLevelRegistration()),
  Routes.branchbalance: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: branchBalanceReportPage()),
  Routes.registercommunity: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'sales', 'sales attendance', 'sales manager','systemadmin'], child: communityRegistration()),
  Routes.generalledger: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: generalLedger()),
  Routes.profitAndLoss: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: const ProfitAndLossPage()),
  Routes.categorysalereport: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: CategorySalesReport()),
  Routes.stocklisttable: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin','warehouse'], child: StockListTable()),
  Routes.journalView: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'accountant','systemadmin'], child: JournalEntryView()),
  Routes.viewfarmers: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'sales attendance', 'sales manager','systemadmin'], child: FarmerListPage()),
  Routes.hampersalereport: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'sales', 'sales attendance', 'sales manager','systemadmin'], child: HamperSalesReport()),
  Routes.stockbalancesync: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer','systemadmin'], child: StockBalanceSync()),
  Routes.SmsConfiguration: (context) => RouteGuard(allowedAccessLevels: ['super admin', 'systemadmin'], child: SmsConfiguration()),
  Routes.supplierreport: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: SupplierReport()),
  Routes.stocktransferlist: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin','warehouse'], child: StockTransferDetailsList()),
  Routes.deletedstock: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: DeletedStockScreen()),
  Routes.momoreport: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: MomoReportPage()),
  Routes.damagereport: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: DamageReport()),
  Routes.debtorreport: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin'], child: DebtorReport()),
  Routes.warehousehomescreen: (context) => RouteGuard(allowedAccessLevels: ['admin', 'super admin', 'operations officers', 'stock officer', 'accountant','systemadmin','warehouse'], child: SupplyQueueHome()),
  Routes.systemadmin: (context) => RouteGuard(allowedAccessLevels: ['super admin','admin','systemadmin'], child: SystemAdminPage()),
  Routes.finishedstock: (context) => RouteGuard(allowedAccessLevels: ['super admin','admin','systemadmin'], child: finishedStockPage()),
  Routes.reorderStock: (context) => RouteGuard(allowedAccessLevels: ['super admin','admin','systemadmin'], child: reOrderStockPage()),
  Routes.collectionmanager: (context) => RouteGuard(allowedAccessLevels: ['super admin','systemadmin'], child: CollectionManagerPage()),
  Routes.salesupload: (context) => RouteGuard(allowedAccessLevels: ['super admin','systemadmin'], child: SalesUploadPage()),
 Routes.synczero: (context) => RouteGuard(allowedAccessLevels: ['super admin','systemadmin'], child: SyncItemtoZero()),
  Routes.updatecostp: (context) => RouteGuard(allowedAccessLevels: ['super admin','systemadmin'], child: StockCostAnalysisPage()),
  Routes.uploadstock: (context) => RouteGuard(allowedAccessLevels: ['super admin','systemadmin'], child: StockUploadPage()),
  Routes.uploadstocktransfer: (context) => RouteGuard(allowedAccessLevels: ['super admin','systemadmin'], child: StockTransferUploadPage()),
  Routes.smsManagement: (context) => RouteGuard(child: Consumer<Datafeed>(builder: (context, datafeed, _) => SMSManagement(companyId: datafeed.companyid, branchId: datafeed.branchid, staffName: datafeed.staff,),),),
  Routes.warehousesupplyreport: (context) => RouteGuard(allowedAccessLevels: ['super admin', 'admin', 'systemadmin', 'operations officers', 'stock officer', 'warehouse'], child: SupplyReportPage()),
  Routes.transactionsupplyreport: (context) => RouteGuard(allowedAccessLevels: ['super admin', 'admin', 'systemadmin', 'operations officers', 'stock officer', 'warehouse'], child: TransactionSupplyReportPage()),
  Routes.stockvaluepage: (context) => RouteGuard(allowedAccessLevels: ['super admin', 'admin', 'systemadmin', 'operations officers', 'stock officer', 'warehouse'], child: StockValuePage()),
  Routes.receivepayments: (context) => RouteGuard(allowedAccessLevels: ['super admin', 'admin', 'systemadmin', 'operations officers', 'stock officer', 'warehouse'], child: ReceivepaymentsPage()),
  Routes.stocktake: (context) => RouteGuard(allowedAccessLevels: ['super admin', 'admin', 'systemadmin', 'operations officers', 'stock officer', 'warehouse'], child: StockTake()),
};
