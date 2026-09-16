
class Mode {
  final String id;
  final String name;
  final String qty;
  final String cp;
  final String rp;
  final String wp;
  final String sp;

  Mode({
    required this.id,
    required this.name,
    required this.qty,
    required this.cp,
    required this.rp,
    required this.wp,
    required this.sp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'qty': qty,
      'cp': cp,
      'rp': rp,
      'wp': wp,
      'sp': sp,
    };
  }


  factory Mode.fromMap(String id, Map<String, dynamic> map) {
    return Mode(
      id: id,
      name: map['name']?.toString() ?? '',
      qty: map['qty']?.toString() ?? '',
      cp: map['cp']?.toString() ?? '',
      rp: map['rp']?.toString() ?? '',
      wp: map['wp']?.toString() ?? '',
      sp: map['sp']?.toString() ?? '',
    );
  }


}