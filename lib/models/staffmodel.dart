import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kologsoft/models/permissionsmodel.dart';

class StaffModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String accesslevel;
  final String branchid;
  final String branchname;
  final List<String> pricingmode;
  final List<String> allowedPaymentMethods;
  final List<String> salesWarehouseIds;
  final List<String> WarehouseIds;
  final List<String> WarehouseNames;
  final List<String> salesWarehouseNames;
  final Map<String, Timestamp>? readupdates;
  final Map<String, ModulePermission>? permissions;
  final Timestamp createdat;
  final String createdby;
  final Timestamp? deletedat;
  final String? deletedby;
  final String companyid;
  final String company;
  final int position;
  final String? imageurl;
  final String? authError;
  final Timestamp? authCreatedAt;
  final Timestamp? positionAssignedAt;
  final bool canPrint;
  final bool canEditPrice;
  final bool canSelectDate;
  final bool canSellAnyBranch;
  final bool allowDiscount;
  final bool allowDiscountCode;
  final DateTime? startdate;
  final DateTime? enddate;
  final String? tempPassword;
  bool? isLoggedIn;
  final Timestamp? lastLogin;
  final Timestamp? lastLogout;
  StaffModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.accesslevel,
    required this.branchid,
    this.startdate,
    this.enddate,
    this.branchname = '',
    this.pricingmode = const [],
    this.allowedPaymentMethods = const [],
    this.salesWarehouseIds = const [],
    this.salesWarehouseNames = const [],
    this.WarehouseIds = const [],
    this.WarehouseNames = const [],
    this.readupdates,
    required this.createdat,
    required this.company,
    required this.createdby,
    this.deletedat,
    this.deletedby,
    required this.companyid,
    this.position = 0,
    this.imageurl,
    this.authError,
    this.authCreatedAt,
    this.positionAssignedAt,
    this.canPrint = false,
    this.canEditPrice = false,
    this.canSellAnyBranch =false,
    this.allowDiscount = false,
    this.allowDiscountCode =false,
    this.permissions,
    this.tempPassword,
    this.lastLogin,
    this.lastLogout,
    this. isLoggedIn,
    this.canSelectDate = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'accesslevel': accesslevel,
    'branchid': branchid,
    'branchname': branchname,
    'pricingmode': pricingmode,
    'allowedPaymentMethods': allowedPaymentMethods,
    'salesWarehouseIds': salesWarehouseIds,
    'salesWarehouseNames': salesWarehouseNames,
    'warehouseids': WarehouseIds,
    'warehousenames': WarehouseNames,
    'readupdates': readupdates,
    'createdat': createdat,
    'createdby': createdby,
    'deletedat': deletedat,
    'deletedby': deletedby,
    'companyid': companyid,
    'position': position,
    'company': company,
    'imageurl': imageurl,
    'authError': authError,
    'authCreatedAt': authCreatedAt,
    'positionAssignedAt': positionAssignedAt,
    'canPrint': canPrint,
    'canEditPrice': canEditPrice,
    'startdate': startdate != null ? Timestamp.fromDate(startdate!) : null,
    'enddate': enddate != null ? Timestamp.fromDate(enddate!) : null,
    'canSelectDate': canSelectDate,
    'canSellAnyBranch': canSellAnyBranch,
    'allowDiscount': allowDiscount,
    'allowDiscountCode': allowDiscountCode,
    'permissions': permissions?.map(
          (module, perm) => MapEntry(module, perm.toMap()),
    ),
  };

  factory StaffModel.fromMap(Map<String, dynamic> map) {
    Timestamp parseTimestamp(dynamic v) {
      if (v == null) return Timestamp.now();
      if (v is Timestamp) return v;
      if (v is String) {
        try {
          return Timestamp.fromDate(DateTime.parse(v));
        } catch (_) {
          return Timestamp.now();
        }
      }
      if (v is DateTime) return Timestamp.fromDate(v);
      return Timestamp.now();
    }

    Timestamp? parseTimestampNullable(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v;
      if (v is String) {
        try {
          return Timestamp.fromDate(DateTime.parse(v));
        } catch (_) {
          return null;
        }
      }
      if (v is DateTime) return Timestamp.fromDate(v);
      return null;
    }
    bool parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      if (v is num) return v == 1;
      return false;
    }
    List<String> parsePricing(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String)
        return v
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      return [v.toString()];
    }

    List<String> parseStringList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String)
        return v
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      return [v.toString()];
    }

    List<String> normalizePaymentMethods(List<String> methods) {
      if (methods.isEmpty) return methods;
      return methods
          .map((m) => m.trim().toLowerCase())
          .where((m) => m.isNotEmpty)
          .map((m) {
        // Accept some legacy/human labels and normalize.
        if (m == 'bank' || m == 'banktransfer' || m == 'bank transfer') {
          return 'bank_transfer';
        }
        if (m == 'mobilemoney' || m == 'mobile money') return 'momo';
        return m.replaceAll(' ', '_');
      })
          .toSet()
          .toList();
    }

    Map<String, Timestamp>? parseReadUpdates(dynamic v) {
      if (v == null) return null;
      if (v is Map) {
        final result = <String, Timestamp>{};
        v.forEach((key, value) {
          if (value is Timestamp) {
            result[key.toString()] = value;
          } else if (value is String) {
            try {
              result[key.toString()] = Timestamp.fromDate(
                DateTime.parse(value),
              );
            } catch (_) {}
          } else if (value is DateTime) {
            result[key.toString()] = Timestamp.fromDate(value);
          }
        });
        return result;
      }
      return null;
    }

    Map<String, ModulePermission> parsePermissions(dynamic value) {
      if (value == null || value is! Map) {
        return {};
      }

      final result = <String, ModulePermission>{};

      value.forEach((key, val) {
        if (val is Map) {
          result[key.toString()] =
              ModulePermission.fromMap(Map<String, dynamic>.from(val));
        }
      });

      return result;
    }
    return StaffModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      company: map['company'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      accesslevel: map['accesslevel'] ?? '',
      branchid: map['branchid'] ?? '',
      branchname: map['branchname'] ?? '',
      pricingmode: parsePricing(map['pricingmode'] ?? map['pricingmode']),
      allowedPaymentMethods: normalizePaymentMethods(
        parseStringList(
          map['allowedPaymentMethods'] ??
              map['allowed_payment_methods'] ??
              map['paymentMethods'] ??
              map['payment_methods'],
        ),
      ),
      salesWarehouseIds: parseStringList(
        map['warehouseids'] ?? // ← Read from warehouseids first (where data is)
            map['warehouseIds'] ??
            map['salesWarehouseIds'] ??
            map['warehouses'],
      ),
      salesWarehouseNames: parseStringList(
        map['warehousenames'] ?? // ← Read from warehousenames first (where data is)
            map['warehouseNames'] ??
            map['salesWarehouseNames'],
      ),
      WarehouseIds: parseStringList(
        map['warehouseids'] ?? // ← Read from warehouseids first (where data is)
            map['warehouseIds'] ??
            map['warehouses'],
      ),
      WarehouseNames: parseStringList(
        map['warehousenames'] ??
            map['warehouseNames'] ??
            map['salesWarehouseNames']
      ),
      readupdates: parseReadUpdates( map['readupdates'] ?? map['read_updates'] ?? map['read'], ),
      createdat: parseTimestamp( map['createdat'] ?? map['date'] ?? map['createdat'], ),
      createdby: map['createdby'] ?? map['createdby'] ?? '',
      deletedat: map['deletedat'],
      deletedby: map['deletedby'] ?? map['deletedby'],
      companyid: map['companyid'] ?? map['companyid'] ?? '',
      position: map['position'] ?? 0,
      canPrint: parseBool(map['canPrint']),
      canEditPrice: parseBool(map['canEditPrice']),
      imageurl: map['imageurl'] ?? map['imageUrl'] ?? map['image'],
      authError: map['authError'] ?? map['auth_error'],
      authCreatedAt: parseTimestampNullable( map['authCreatedAt'] ?? map['auth_created_at'],),
      positionAssignedAt: parseTimestampNullable( map['positionAssignedAt'] ?? map['position_assigned_at'],),

      startdate: map['startdate'] is Timestamp ? (map['startdate'] as Timestamp).toDate() : null,
      enddate: map['enddate'] is Timestamp ? (map['enddate'] as Timestamp).toDate() : null,
      permissions: parsePermissions(map['permissions']),
      tempPassword:map['tempPassword'],
      isLoggedIn:map['isLoggedIn'],
      lastLogin:map['lastLogin'],
      lastLogout:map['lastLogout'],
      canSelectDate: parseBool(map['canSelectDate']),
      canSellAnyBranch: parseBool(map['canSellAnyBranch']),
      allowDiscount: parseBool(map['allowDiscount']),
      allowDiscountCode: parseBool(map['allowDiscountCode']),

    );
  }
}