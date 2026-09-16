import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/constants.dart';
import '../models/appModuls.dart';

class UserPermissionScreen extends StatefulWidget {
  final String? userId;
  final String? userName;
  final bool isEditing;

  const UserPermissionScreen({
    super.key,
    this.userId,
    this.userName,
    this.isEditing = false,
  });

  @override
  State<UserPermissionScreen> createState() => _UserPermissionScreenState();
}

class _UserPermissionScreenState extends State<UserPermissionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _roleController = TextEditingController();
  String _selectedRole = 'sales';
  bool _isLoading = false;

  // Permission structure
  late Map<String, Map<String, bool>> _permissions;

  final List<String> _roles = ['admin', 'manager', 'sales', 'viewer'];

  @override
  void initState() {
    super.initState();
    _initializePermissions();
    if (widget.isEditing && widget.userId != null) {
      _loadUserPermissions(widget.userId!);
    }
  }

  void _initializePermissions() {
    _permissions = {
      AppModules.dashboard: {
        'view': true,
        'settings': false,
      },
      AppModules.userManagement: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.accounts: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.stock: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.sales: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
        'print': false,
      },
      AppModules.FarmerManagement: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.settings: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.reports: {
        'view': false,
        'print': false,
        'export': false,
      },
    };
  }

  Future<void> _loadUserPermissions(String userId) async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('staff').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _userNameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _roleController.text = data['accesslevel'] ?? '';
        _selectedRole = data['accesslevel'] ?? 'sales';

        // Load permissions
        final permissions = data['permissions'] as Map<String, dynamic>?;
        if (permissions != null) {
          _permissions.forEach((module, modulePermissions) {
            final moduleData = permissions[module] as Map<String, dynamic>?;
            if (moduleData != null) {
              modulePermissions.forEach((permission, _) {
                modulePermissions[permission] = moduleData[permission] ?? false;
              });
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading permissions: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  void _togglePermission(String module, String permission) {
    setState(() {
      _permissions[module]![permission] = !_permissions[module]![permission]!;
    });
  }

  void _selectAll(String module, bool value) {
    setState(() {
      _permissions[module]!.forEach((key, _) {
        _permissions[module]![key] = value;
      });
    });
  }

  Future<void> _savePermissions() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    LoadingDialog.show(
      context,
      message: "Please wait...",
    );

    try {
      final userData = {
        'permissions': _permissions,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.isEditing && widget.userId != null) {
        // Update existing user
        await _firestore.collection('staff').doc(widget.userId).set(userData, SetOptions(merge: true));
        // print("permissions $_permissions");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permissions updated successfully'), backgroundColor: Colors.green),
        );
      } else {
        // Create new user with permissions
        final userID=_emailController.text.toString();
        userData['createdAt'] = FieldValue.serverTimestamp();
        userData['isActive'] = true;
        await _firestore.collection('staff').doc(userID).set(userData, SetOptions(merge: true));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User permissions created successfully'), backgroundColor: Colors.green),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving permissions: $e'), backgroundColor: Colors.red),
      );
    }finally {
      LoadingDialog.hide();
    }

    setState(() => _isLoading = false);
  }

  Widget _buildPermissionCard(String module, List<String> permissions) {
    final isDashboard = module == 'Dashboard';
    final modulePermissions =  _permissions[module] ??
        {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
        };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      color: const Color(0xFF1B263B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Module Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    module,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isDashboard)
                  TextButton(
                    onPressed: () {
                      final allSelected = modulePermissions.values.every((v) => v);
                      _selectAll(module, !allSelected);
                    },
                    child: Text(
                      modulePermissions.values.every((v) => v)
                          ? 'Deselect All'
                          : 'Select All',
                      style: TextStyle(
                        color: Colors.blue.shade300,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),

            // Permission Toggles
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: permissions.map((permission) {
                final isEnabled = modulePermissions[permission] ?? false;

                // Handle special dashboard settings
                if (isDashboard && permission == 'settings') {
                  return const SizedBox.shrink();
                }

                return SizedBox(
                  width: 120,
                  child: Row(
                    children: [
                      Checkbox(
                        value: isEnabled,
                        onChanged: (value) => _togglePermission(module, permission),
                        activeColor: Colors.blue,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      Expanded(
                        child: Text(
                          permission.toUpperCase(),
                          style: TextStyle(
                            color: isEnabled ? Colors.white : Colors.white54,
                            fontSize: 12,
                            fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Permissions' : 'New User Permissions'),
        backgroundColor: const Color(0xFF1B263B),
        elevation: 0,
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deleteUser,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? 500 : isTablet ? 800 : 1200,
                minWidth: 300,
              ),
              child: Column(
                children: [
                  // User Information Card
                  Card(
                    color: const Color(0xFF1B263B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 600,
                            ),
                            child: TextFormField(
                              controller: _userNameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                labelStyle: TextStyle(color: Colors.white54),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                                filled: true,
                                fillColor: Color(0xFF22304A),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter user name';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 600,
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: TextStyle(color: Colors.white54),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                                filled: true,
                                fillColor: Color(0xFF22304A),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 600,
                            ),
                            child: TextFormField(
                              controller: _roleController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Access Level',
                                labelStyle: TextStyle(color: Colors.white54),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                                filled: true,
                                fillColor: Color(0xFF22304A),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter user name';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Permissions Section
                  const Text(
                    'PERMISSIONS',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Permission Cards with constraints
                  if (isMobile)
                    Column(
                      children: [
                        _buildPermissionCard(AppModules.dashboard, ['view', 'settings']),
                        _buildPermissionCard(AppModules.userManagement, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.settings, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.accounts, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.stock, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.sales, ['view', 'create', 'edit','delete','print']),
                        _buildPermissionCard(AppModules.FarmerManagement, ['view', 'create','edit', 'delete']),
                        _buildPermissionCard(AppModules.reports, ['view', 'print', 'export']),
                      ],
                    )
                  else if (isTablet)
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.8,
                      children: [
                        _buildPermissionCard(AppModules.dashboard, ['view', 'settings']),
                        _buildPermissionCard(AppModules.userManagement, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.settings, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.accounts, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.stock, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.sales, ['view', 'create', 'edit','delete','print']),
                        _buildPermissionCard(AppModules.FarmerManagement, ['view', 'create','edit', 'delete']),
                        _buildPermissionCard(AppModules.reports, ['view', 'print', 'export']),
                      ],
                    )
                  else
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: [
                        _buildPermissionCard(AppModules.dashboard, ['view', 'settings']),
                        _buildPermissionCard(AppModules.userManagement, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.settings, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.accounts, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.stock, ['view', 'create', 'edit', 'delete']),
                        _buildPermissionCard(AppModules.sales, ['view', 'create', 'edit','delete','print']),
                        _buildPermissionCard(AppModules.FarmerManagement, ['view', 'create','edit', 'delete']),
                        _buildPermissionCard(AppModules.reports, ['view', 'print', 'export']),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Save Button with constraints
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 500,
                      minWidth: 200,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _savePermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF415A77),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _isLoading
                              ? 'Saving...'
                              : widget.isEditing
                              ? 'Update Permissions'
                              : 'Create User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setPermissionsByRole(String role) {
    switch (role) {
      case 'admin':
        _permissions.forEach((module, modulePermissions) {
          modulePermissions.forEach((permission, _) {
            modulePermissions[permission] = true;
          });
        });
        break;
      case 'manager':
        _setManagerPermissions();
        break;
      case 'sales':
        _setStaffPermissions();
        break;
      case 'viewer':
        _setViewerPermissions();
        break;
    }
  }

  void _setManagerPermissions() {
    _permissions = {
      AppModules.dashboard: {
        'view': true,
        'settings': false,
      },
      AppModules.userManagement: {
        'view': true,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.accounts: {
        'view': true,
        'create': true,
        'edit': true,
        'delete': false,
      },
      AppModules.stock: {
        'view': true,
        'create': true,
        'edit': true,
        'delete': false,
      },
      AppModules.sales: {
        'view': true,
        'create': true,
        'edit': true,
        'delete': false,
        'print': true,
      },
      AppModules.FarmerManagement: {
        'view': true,
        'create': true,
        'edit': true,
        'delete': false,
      },
      AppModules.settings: {
        'view': true,
        'create': true,
        'edit': true,
        'delete': false,
      },
      AppModules.reports: {
        'view': true,
        'print': true,
        'export': false,
      },
    };
  }

  void _setStaffPermissions() {
    _permissions = {
      AppModules.dashboard: {
        'view': true,
        'settings': false,
      },
      AppModules.userManagement: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.accounts: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.stock: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.sales: {
        'view': true,
        'create': true,
        'edit': true,
        'delete': false,
        'print': false,
      },
      AppModules.reports: {
        'view': true,
        'print': false,
        'export': false,
      },
    };
  }

  void _setViewerPermissions() {
    _permissions = {
      AppModules.dashboard: {
        'view': true,
        'settings': false,
      },
      AppModules.userManagement: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.accounts: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.FarmerManagement: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.settings: {
        'view': false,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.stock: {
        'view': true,
        'create': false,
        'edit': false,
        'delete': false,
      },
      AppModules.sales: {
        'view': true,
        'create': false,
        'edit': false,
        'delete': false,
        'print': true,
      },
      AppModules.reports: {
        'view': true,
        'print': false,
        'export': false,
      },
    };
  }

  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text(
          'Delete User',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this user and their permissions?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && widget.userId != null) {
      setState(() => _isLoading = true);
      try {
        await _firestore.collection('staff').doc(widget.userId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    super.dispose();
  }
}