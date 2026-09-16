import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/screens/systemadminregcompany.dart';
import 'package:kologsoft/screens/tierfeature.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/routes.dart';
import 'companyreg.dart';

class SystemAdminPage extends StatefulWidget {
	const SystemAdminPage({Key? key}) : super(key: key);

	@override
	State<SystemAdminPage> createState() => _SystemAdminPageState();
}

class _SystemAdminPageState extends State<SystemAdminPage> {
	final FirebaseFirestore _db = FirebaseFirestore.instance;
	List<QueryDocumentSnapshot> _companies = [];
	bool _loading = true;
	String? _error;
	Map<String, DateTime?> _companyLastUpdate = {};
	bool _loadingUpdates = true;

	Future<DateTime?> _getLatestStockUpdate(String companyId) async {

		try {
			final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
			final q = await _db
					.collection('stockreport')
					.where('companyid', isEqualTo: companyId)
					.where('summarydate', isEqualTo: todayStr)
					.orderBy('lastupdate', descending: true)
					.limit(1)
					.get();

			if (q.docs.isEmpty) return null;
			final v = q.docs.first.data()['lastupdate'];
			if (v == null) return null;
			if (v is Timestamp) return v.toDate();
			if (v is DateTime) return v;
			if (v is String) return DateTime.tryParse(v);
			return null;
		} catch (e) {
			print(e);
		}
	}

	Future<void> _loadCompanies() async {
		if (mounted) {
			setState(() {
				_loading = true;
				_error = null;
			});
		}
		try {
			final q = await _db.collection('companies').get();
			if (!mounted) return;
			setState(() {
				_companies = q.docs;
				_loading = false;
			});
			// after loading companies, prefetch last updates
			await _loadCompanyLastUpdates();
		} catch (e) {
			if (!mounted) return;
			setState(() {
				_error = e.toString();
				_loading = false;
			});
		}
	}

	Future<void> _loadCompanyLastUpdates() async {
		if (_companies.isEmpty) {
			if (mounted) {
				setState(() {
					_companyLastUpdate = {};
					_loadingUpdates = false;
				});
			}
			return;
		}

		if (mounted) {
			setState(() {
				_loadingUpdates = true;
			});
		}

		final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

		try {
    final String companyid ='KS005';
			final q = await _db
					.collection('stockreport')
					.where('summarydate', isEqualTo: todayStr)
					.orderBy('lastupdate', descending: true)
					.get();

			final Map<String, DateTime?> map = {};
			for (final doc in q.docs) {
				final data = doc.data() as Map<String, dynamic>? ?? {};
				final cid = (data['companyid'] );
				if (cid == null) continue;
				if (map.containsKey(cid)) continue;
				final v = data['lastupdate'];
				DateTime? dt;
				if (v is Timestamp) dt = v.toDate();
				else if (v is DateTime) dt = v;
				else if (v is String) dt = DateTime.tryParse(v);
				map[cid] = dt;
			}

			// ensure all companies have an entry (null if none)
			for (final c in _companies) {
				final data = c.data() as Map<String, dynamic>? ?? {};
				final cid = (data['companyid'] ?? data['id'] ?? c.id).toString();
				if (!map.containsKey(cid)) map[cid] = null;
			}

			if (!mounted) return;
			setState(() {
				_companyLastUpdate = map;
				_loadingUpdates = false;
			});
		} catch (e) {
      print(e);
			if (!mounted) return;
			setState(() {
				_companyLastUpdate = {};
				_loadingUpdates = false;
			});
		}
	}

	@override
	void initState() {
		super.initState();
		_loadCompanies();
	}

	Map<String, dynamic> _statusFromLastUpdate(DateTime? last) {

		if (last == null) return {'label': 'No data', 'color': Colors.grey};
		final diff = DateTime.now().difference(last).inMinutes;
		if (diff < 11) return {'label': 'Online', 'color': Colors.green};
		if (diff < 30) return {'label': 'Active', 'color': Colors.orange};
		return {'label': 'Inactive', 'color': Colors.red};
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
		final screenWidth = MediaQuery.sizeOf(context).width;
		return Consumer<Datafeed>(
		  builder: (BuildContext context, Datafeed value, Widget? child) {
         return Scaffold(
          appBar: AppBar(
            title: const Text('System Admin - Companies'),
						actions: [

								// ListTile(
								// 	leading: const Icon(
								// 		Icons.tune,
								// 		color: Colors.white,
								// 	),
								// 	title: const Text(
								// 		'Subscription Tiers',
								// 		style: TextStyle(color: Colors.white),
								// 	),
								// 	onTap: () {
								// 		Navigator.push(
								// 			context,
								// 			MaterialPageRoute(builder: (_) => const TierFeatureConfigScreen()),
								// 		);
								// 	},
								// ),
								const Divider(color: Colors.white24),


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
												if (value.staffemail.isNotEmpty)
													Text(
														value.staffemail,
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
									//register company
									PopupMenuItem<String>(
										value: 'register_company',
										child: Row(
											children: const [
												Icon(
													Icons.business_outlined,
													size: 20,
													color: Colors.green,
												),
												SizedBox(width: 12),
												Text(
													'Register Company',
													style: TextStyle(
														color: Colors.black87,
													),
												),
											],
										),
									),
									PopupMenuItem<String>(
										value: 'Subscription Tiers',
										child: Row(
											children: const [
												Icon(
													Icons.business_outlined,
													size: 20,
													color: Colors.green,
												),
												SizedBox(width: 12),
												Text(
													'Subscription Tiers',
													style: TextStyle(
														color: Colors.black87,
													),
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
									}
									else if(selectedValue=='register_company'){
										Navigator.push(context,
												MaterialPageRoute(
														builder: (context) => const CompanyRegPageAdmin()));
									}
									else if(selectedValue =='Subscription Tiers'){
										Navigator.push(
												context,
												MaterialPageRoute(builder: (_) => const TierFeatureConfigScreen()),
										);
									}
								},
							),

						],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('Error: $_error'))
              : _companies.isEmpty
              ? const Center(child: Text('No companies'))
              : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _companies.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = _companies[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final companyName = data['company']  ?? doc.id;
              final companyId = data['companyid'] ?? data['id'] ?? doc.id;
              final companyemail = data['email']?? '';
              final address =data['address']?? '';
              final name =data['name']?? '';
              final phone =data['phone']?? '';
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: CircleAvatar(
                    child: Text((companyName as String).isNotEmpty ? companyName[0].toUpperCase() : '?'),
                  ),
                  title: Text(companyName),
                  subtitle: (_loadingUpdates)
                      ? const Text('Loading status...')
                      : Builder(builder: (context) {
                    final last = _companyLastUpdate[companyId.toString()];
                    final status = _statusFromLastUpdate(last);
                    final label = status['label'] as String;
                    final color = status['color'] as Color;
                    final lastStr = last != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(last) : '—';
                    return Wrap(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(label),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 14),
                        const SizedBox(width: 4),
                        Text(lastStr,softWrap: true,
														maxLines: 2,
														style: const TextStyle(fontSize: 12)),
                      ],
                    );
                  }),
									trailing: Wrap(
									//	mainAxisSize: MainAxisSize.min,
										children: [
											IconButton(
												icon: const Icon(Icons.edit, color: Colors.amber),
												onPressed: () {
													Navigator.push(
														context,
														MaterialPageRoute(
															builder: (_) => CompanyRegPage(
																docId: doc.id,
																data: data,
															),
														),
													);
												},
											),
											IconButton(
												icon: const Icon(Icons.open_in_new),
												onPressed: () async {
													final datafeed = context.read<Datafeed>();
													await datafeed.loginAsCompanyAdmin(
														companyId: companyId.toString(),
														companyName: companyName,
														companyEmailVal: companyemail,
														companyPhoneVal: phone,
														staffName: name,
													);
													if (context.mounted) {
														Navigator.pushNamedAndRemoveUntil(context, Routes.home, (route) => false);
													}
												},
											),
										],
									),

                ),
              );
            },
          ),
        );
      },
		);
	}
}

