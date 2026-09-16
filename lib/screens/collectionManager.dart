// lib/pages/collection_manager_page.dart
//
// Admin page: lists all Firestore collections, lets a super admin
// multi-select them, and clears documents belonging to the caller's
// own company from the selected collections, after a Staff ID check.
//
// Requires:
//   cloud_firestore, cloud_functions, firebase_auth
//
// Assumes a `staff/{email}` profile document with fields:
//   staffId      (String)
//   accessLevel  (String, e.g. "staff" | "admin" | "super admin")
//   companyid    (String)
//
// IMPORTANT: this must stay in sync with functions/index.js —
// specifically the "staff" collection name, the doc-id-by-email
// lookup, the "super admin" access level string, and the "companyid"
// field name. If you rename any of these in Firestore, update both
// files together.
//
// The client-side checks here are for UX (fast feedback, no wasted
// round-trip). The Cloud Function `clearFirestoreCollections` is the
// real gate — it re-validates staffId, accessLevel, and companyid
// server-side before deleting anything, so this page stays safe even
// if someone tampers with the client.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CollectionManagerPage extends StatefulWidget {
  const CollectionManagerPage({super.key});

  @override
  State<CollectionManagerPage> createState() => _CollectionManagerPageState();
}

class _CollectionManagerPageState extends State<CollectionManagerPage> {
  final _functions = FirebaseFunctions.instance;

  bool _loading = true;
  String? _loadError;

  List<String> _collections = [];
  final Set<String> _selected = {};

  String? _staffId;
  String? _accessLevel;
  // Read for display purposes only — the actual company scoping used
  // for deletion is re-derived server-side by the Cloud Function from
  // the caller's own staff doc, not from anything this client sends.
  String? _companyId;
  bool _profileLoaded = false;

  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadProfileAndCollections();
  }

  Future<void> _loadProfileAndCollections() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      await Future.wait([_loadCallerProfile(), _loadCollections()]);
    } catch (e) {
      print('Error loading profile or collections: $e');
      _loadError = _friendlyError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCallerProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not signed in.');
    }
    if (user.email == null) {
      throw Exception('Signed-in account has no email — cannot look up staff profile.');
    }
    final doc = await FirebaseFirestore.instance
        .collection('staff')
        .doc(user.email)
        .get();
    if (!doc.exists) {
      throw Exception('No staff profile found for this account.');
    }
    final data = doc.data()!;
    _staffId = data['email'] as String?;
    _accessLevel = data['accesslevel'] as String?;
    _companyId = data['companyid'] as String?;
    _profileLoaded = true;
  }

  Future<void> _loadCollections() async {
    final result =
    await _functions.httpsCallable('listFirestoreCollections').call();
    final names = List<String>.from(result.data['collections'] as List);
    setState(() => _collections = names);
  }

  bool get _isSuperAdmin => _accessLevel == 'super admin';

  void _toggleSelection(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  void _selectAll() {
    setState(() => _selected.addAll(_collections));
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  Future<void> _onDeletePressed() async {
    if (_selected.isEmpty) return;

    if (!_profileLoaded) {
      _showSnack('Still loading your profile — try again in a moment.');
      return;
    }

    if (!_isSuperAdmin) {
      _showSnack('Only super admins can clear data.');
      return;
    }

    if (_companyId == null || _companyId!.isEmpty) {
      _showSnack('Your profile has no company set — cannot proceed.');
      return;
    }

    final enteredId = await _promptForStaffId();
    if (enteredId == null) return; // cancelled

    if (enteredId.trim() != (_staffId ?? '').trim()) {
      _showSnack('Staff ID does not match. Deletion cancelled.');
      return;
    }

    final confirmed = await _confirmFinalWarning();
    if (confirmed != true) return;

    await _performDelete(enteredId.trim());
  }

  Future<String?> _promptForStaffId() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Staff ID'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your Staff ID to confirm deletion of your company\'s '
                    'data in ${_selected.length} collection(s):',
              ),
              const SizedBox(height: 8),
              Text(
                _selected.join(', '),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Staff ID',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmFinalWarning() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('This cannot be undone'),
        content: Text(
          'Every document belonging to your company will be permanently '
              'deleted from these ${_selected.length} collection(s) — other '
              'companies\' data is left untouched:\n\n${_selected.join(', ')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(String staffId) async {
    setState(() => _deleting = true);
    try {
      final result = await _functions
          .httpsCallable('clearFirestoreCollections')
          .call({
        'collectionNames': _selected.toList(),
        'staffId': staffId,
      });

      final counts = Map<String, dynamic>.from(result.data['deletedCounts']);
      final total = counts.values.fold<int>(0, (sum, v) => sum + (v as int));

      _showSnack(
        'Cleared $total document(s) belonging to your company across '
            '${counts.length} collection(s).',
      );
      setState(() => _selected.clear());
    } on FirebaseFunctionsException catch (e) {
      _showSnack(e.message ?? 'Deletion failed.');
    } catch (e) {
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object e) {
    if (e is FirebaseFunctionsException) return e.message ?? e.code;
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Manager'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadProfileAndCollections,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _selected.isEmpty ? null : _buildActionBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadProfileAndCollections,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_collections.isEmpty) {
      return const Center(child: Text('No collections found.'));
    }

    return Column(
      children: [
        if (!_isSuperAdmin)
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Text(
              'Viewing only — your account is not a super admin, '
                  'so deletion is disabled.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text('${_selected.length} of ${_collections.length} selected'),
              const Spacer(),
              TextButton(onPressed: _selectAll, child: const Text('Select all')),
              TextButton(onPressed: _clearSelection, child: const Text('Clear')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: _collections.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final name = _collections[i];
              final checked = _selected.contains(name);
              return CheckboxListTile(
                value: checked,
                onChanged: (_) => _toggleSelection(name),
                title: Text(name),
                secondary: const Icon(Icons.folder_outlined),
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _deleting ? null : _onDeletePressed,
          icon: _deleting
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Icon(Icons.delete_forever),
          label: Text(_deleting
              ? 'Deleting…'
              : 'Delete company data in ${_selected.length} collection(s)'),
        ),
      ),
    );
  }
}