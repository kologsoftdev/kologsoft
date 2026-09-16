class ModulePermission {
  final bool view;
  final bool create;
  final bool edit;
  final bool delete;
  final bool print;

  const ModulePermission({
    this.view = false,
    this.create = false,
    this.edit = false,
    this.delete = false,
    this.print = false,
  });

  factory ModulePermission.fromMap(Map<String, dynamic> map) {
    return ModulePermission(
      view: map['view'] ?? false,
      create: map['create'] ?? false,
      edit: map['edit'] ?? false,
      delete: map['delete'] ?? false,
      print: map['print'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'view': view,
      'create': create,
      'edit': edit,
      'delete': delete,
      'print': print,
    };
  }
}