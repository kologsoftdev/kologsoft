
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../providers/routes.dart';
import 'role_access_config.dart';

class RoleAccessDashboard extends StatefulWidget {
  const RoleAccessDashboard({super.key});

  @override
  State<RoleAccessDashboard> createState() => _RoleAccessDashboardState();
}

class _RoleAccessDashboardState extends State<RoleAccessDashboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final datafeed = context.read<Datafeed>();
      if (datafeed.roleAccessSelections == null &&
          !datafeed.roleAccessLoading &&
          !datafeed.roleAccessError) {
        datafeed.loadRoleAccessSelections();
      }
    });

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

  void _showLogoutDialog(BuildContext parentcontext, Datafeed datafeed) {
    showDialog(
      context: parentcontext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                datafeed.logout(parentcontext);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final datafeed = context.watch<Datafeed>();
    final roleLabel = _formatRoleName(datafeed.accesslevel);
    double screenWidth = MediaQuery.of(context).size.width;
    final isLoading =
        datafeed.roleAccessLoading && datafeed.roleAccessSelections == null;
    final hasError =
        datafeed.roleAccessError && datafeed.roleAccessSelections == null;
    final selections = datafeed.roleAccessSelections ??
        (isLoading ? const <String, List<String>>{} : getDefaultRoleAccessSelections());
    final actions = isLoading
        ? const <RoleAccessAction>[]
        : buildRoleAccessActions(
      datafeed.accesslevel,
      roleSelections: selections,
    );

    final Widget bodyContent;
    if (isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (hasError) {
      bodyContent = Center(
        child: Text(
          'Unable to load role access selections. Please try again.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      );
    } else if (actions.isEmpty) {
      bodyContent = const Center(
        child: Text('No role-based actions are available yet.'),
      );
    } else {
      bodyContent = LayoutBuilder(
        builder: (context, constraints) {
          final double maxCrossAxisExtent = constraints.maxWidth < 680
              ? constraints.maxWidth
              : constraints.maxWidth < 1080
              ? 320
              : constraints.maxWidth < 1400
              ? 300
              : 280;

          return GridView.builder(
            padding: const EdgeInsets.only(top: 4),
            itemCount: actions.length,
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxCrossAxisExtent,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.16,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (action.route.isNotEmpty) {
                    Navigator.pushNamed(context, action.route);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.onSurface.withOpacity(0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.35)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: action.color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              action.icon,
                              color: action.color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              action.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        action.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.72),
                          height: 1.35,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            action.badge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Access - $roleLabel'),
            Text(
              datafeed.company.isEmpty ? 'Role Access' : datafeed.company,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimary.withOpacity(0.88),
              ),
            ),
          ],
        ),
        actions: [

          if (actions.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu_open),
              tooltip: 'Quick links',
              onSelected: (value) {
                final action = actions.firstWhere((item) => item.id == value);
                if (action.route.isNotEmpty) {
                  Navigator.pushNamed(context, action.route);
                }
              },
              itemBuilder: (context) => actions
                  .map(
                    (action) => PopupMenuItem<String>(
                  value: action.id,
                  child: Row(
                    children: [
                      Icon(action.icon, size: 18, color: action.color),
                      const SizedBox(width: 10),
                      Expanded(child: Text(action.title)),
                    ],
                  ),
                ),
              )
                  .toList(),
            ),
            PopupMenuButton<String>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 16,
                  child: Text(
                    datafeed.staff.isNotEmpty
                        ? datafeed.staff[0].toUpperCase()
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
                    datafeed.staff.isNotEmpty ? datafeed.staff : 'User',
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
                      datafeed.staff.isNotEmpty ? datafeed.staff : 'User',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    if (datafeed.staffemail.isNotEmpty)
                      Text(
                        datafeed.staffemail,
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
                _showLogoutDialog(context, datafeed);
              } else if (selectedValue == 'password') {
                _showChangePasswordDialog(context, datafeed);
              } else if (selectedValue == 'profile') {
                Navigator.pushNamed(context, Routes.staffprofile);
              }
            },
          ),

        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.35)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: colorScheme.onSurface.withOpacity(0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${datafeed.staff.isEmpty ? 'User' : datafeed.staff}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Use the menu below to open the modules available for your role.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: bodyContent),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRoleName(String accessLevel) {
    final normalized = accessLevel.trim();
    if (normalized.isEmpty) return 'User';
    return normalized.replaceAll(' ', ' ');
  }
}