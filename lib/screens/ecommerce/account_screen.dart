import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        backgroundColor: const Color(0xFF131921),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1200;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 40 : 16,
              vertical: 24,
            ),
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 800 : double.infinity,
                ),
                child: Column(
                  children: [
                    // Profile Section
                    _buildProfileCard(user, isDesktop),
                    const SizedBox(height: 24),

                    // Account Options
                    _buildOptionCard(
                      icon: Icons.person,
                      title: 'Profile Information',
                      subtitle: 'Update your name, email and phone',
                      onTap: () {
                        // Navigate to profile edit
                      },
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(height: 16),

                    _buildOptionCard(
                      icon: Icons.location_on,
                      title: 'Saved Addresses',
                      subtitle: 'Manage your delivery addresses',
                      onTap: () {
                        // Navigate to addresses
                      },
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(height: 16),

                    _buildOptionCard(
                      icon: Icons.payment,
                      title: 'Payment Methods',
                      subtitle: 'Manage your payment options',
                      onTap: () {
                        // Navigate to payment methods
                      },
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(height: 16),

                    _buildOptionCard(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      subtitle: 'Manage notification preferences',
                      onTap: () {
                        // Navigate to notifications
                      },
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(height: 16),

                    _buildOptionCard(
                      icon: Icons.help,
                      title: 'Help & Support',
                      subtitle: 'Get help with your orders',
                      onTap: () {
                        // Navigate to help
                      },
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(height: 16),

                    _buildOptionCard(
                      icon: Icons.info,
                      title: 'About',
                      subtitle: 'App version and information',
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'KologShop',
                          applicationVersion: '1.0.0',
                          applicationIcon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'KS',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF131921),
                              ),
                            ),
                          ),
                        );
                      },
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(height: 32),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Logout'),
                              content: const Text(
                                'Are you sure you want to logout?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Logout'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/login',
                                (route) => false,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(User? user, bool isDesktop) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 32 : 24),
        child: Row(
          children: [
            CircleAvatar(
              radius: isDesktop ? 50 : 40,
              backgroundColor: const Color(0xFFFF6B35),
              child: Text(
                user?.displayName?.substring(0, 1).toUpperCase() ??
                    user?.email?.substring(0, 1).toUpperCase() ??
                    'U',
                style: TextStyle(
                  fontSize: isDesktop ? 32 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: isDesktop ? 24 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? 'Guest User',
                    style: TextStyle(
                      fontSize: isDesktop ? 24 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'guest@example.com',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDesktop,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 20 : 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFFF6B35),
                  size: isDesktop ? 28 : 24,
                ),
              ),
              SizedBox(width: isDesktop ? 20 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: isDesktop ? 20 : 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
