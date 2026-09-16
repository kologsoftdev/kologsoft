//
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../providers/Datafeed.dart';
// import '../services/sales_import_service.dart';
//
// class SalesUploadPage extends StatefulWidget {
//   const SalesUploadPage({super.key});
//
//   @override
//   State<SalesUploadPage> createState() => _SalesUploadPageState();
// }
//
// /// Kept only so old call sites that reference `SalesUploadWithoutValidate`
// /// still compile — it now renders the exact same page.
// class SalesUploadWithoutValidate extends StatelessWidget {
//   const SalesUploadWithoutValidate({super.key});
//
//   @override
//   Widget build(BuildContext context) => const SalesUploadPage();
// }
//
// class _SalesUploadPageState extends State<SalesUploadPage> {
//   bool _syncing = false;
//   ApiSyncResult? _lastResult;
//   DateTime? _lastSyncAt;
//   String? _lastError;
//
//   SalesImportService get _service => context.read<Datafeed>().salesImport;
//
//   void _snack(String msg, Color color) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
//   }
//
//   Future<void> _syncFromApi() async {
//     if (_syncing) return;
//
//     print('[UI] Sync button pressed');
//
//     final datafeed = context.read<Datafeed>();
//     try {
//       if (datafeed.companyid.isEmpty) {
//         print('[UI] Missing companyid/branchid — calling getdata()');
//         await datafeed.getdata();
//       }
//     } catch (e, st) {
//       print('[UI] datafeed.getdata() failed: $e');
//       print(st);
//       _snack('Could not load account info: $e', Colors.red);
//       return;
//     }
//
//     if (!mounted) return;
//     if (datafeed.companyid.isEmpty) {
//       print('[UI] companyid still empty after getdata()');
//       _snack('No company context found. Please log in again.', Colors.red);
//       return;
//     }
//     if (datafeed.branchid.isEmpty) {
//       print('[UI] branchid still empty after getdata()');
//       _snack('No branch context found for your account. Please log in again.', Colors.red);
//       return;
//     }
//
//     setState(() {
//       _syncing = true;
//       _lastError = null;
//     });
//
//     try {
//       print('[UI] Calling syncFromExternalApi...');
//       final result = await _service.syncFromExternalApi(
//         datafeed: datafeed,
//         companyId: datafeed.companyid,
//         companyName: datafeed.company,
//         staffPosition: datafeed.staffPosition.toString(),
//         staffName: datafeed.staff,
//         staffEmail: datafeed.staffemail,
//         defaultBranchId: datafeed.branchid,
//       );
//
//       print('[UI] Sync succeeded: $result');
//
//       if (!mounted) return;
//       setState(() {
//         _lastResult = result;
//         _lastSyncAt = DateTime.now();
//       });
//
//       if (result.uploaded == 0 && result.fetched == 0) {
//         _snack('No sales returned by the POS API.', Colors.teal);
//       } else if (result.uploaded == 0 && result.skipped > 0) {
//         _snack('Nothing new — ${result.skipped} sale(s) already synced.', Colors.teal);
//       } else if (result.failed > 0) {
//         _snack(
//           'Synced ${result.uploaded} sale(s), ${result.failed} failed, ${result.skipped} already synced.',
//           Colors.orange,
//         );
//       } else {
//         _snack(
//           'Synced ${result.uploaded} sale(s) from the POS API (${result.skipped} already synced, skipped).',
//           Colors.green,
//         );
//       }
//     } catch (e, st) {
//       print('[UI] Sync FAILED: $e');
//       print(st);
//       if (!mounted) return;
//       setState(() => _lastError = e.toString());
//       _snack('POS API sync failed: $e', Colors.red);
//     } finally {
//       if (mounted) setState(() => _syncing = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isMobile = MediaQuery.of(context).size.width < 768;
//
//     return Scaffold(
//       backgroundColor: const Color(0xFF101624),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF1B263B),
//         title: const Text('Sync Sales from POS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
//         elevation: 0,
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 20),
//           child: Center(
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 800),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildApiSyncSection(),
//                   if (_lastResult != null) ...[
//                     const SizedBox(height: 24),
//                     _buildResultSummary(),
//                   ],
//                   if (_lastResult?.errors.isNotEmpty ?? false) ...[
//                     const SizedBox(height: 16),
//                     _buildErrorsList(_lastResult!.errors),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildApiSyncSection() {
//     return Container(
//       decoration: BoxDecoration(
//         color: const Color(0xFF22304A),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.white12),
//       ),
//       padding: const EdgeInsets.all(20),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.sync, color: _syncing ? Colors.lightBlue : Colors.white70, size: 24),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Sync from POS API',
//                       style: Theme.of(context)
//                           .textTheme
//                           .titleMedium
//                           ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
//                     ),
//                     const SizedBox(height: 4),
//                     const Text(
//                       'Pulls unsynced sales (sync_status "0") from the connected POS, uploads the new ones, '
//                           'and reports the ids back so the POS can mark them synced. Already-synced sales are '
//                           'skipped automatically.',
//                       style: TextStyle(color: Colors.white54, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: ElevatedButton.icon(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _syncing ? Colors.grey : Colors.teal,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                 elevation: 0,
//               ),
//               onPressed: _syncing ? null : _syncFromApi,
//               icon: _syncing
//                   ? const SizedBox(
//                 width: 18,
//                 height: 18,
//                 child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
//               )
//                   : const Icon(Icons.cloud_sync),
//               label: Text(_syncing ? 'Syncing…' : 'Sync Now', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//             ),
//           ),
//           if (_lastError != null) ...[
//             const SizedBox(height: 12),
//             Text(_lastError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
//           ],
//         ],
//       ),
//     );
//   }
//
//   Widget _buildResultSummary() {
//     final result = _lastResult!;
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         if (_lastSyncAt != null)
//           Padding(
//             padding: const EdgeInsets.only(bottom: 12),
//             child: Text(
//               'Last sync at ${_lastSyncAt!.toLocal().toString().split('.').first} — ${result.fetched} row(s) fetched from the API.',
//               style: const TextStyle(color: Colors.white54, fontSize: 12),
//             ),
//           ),
//         Row(
//           children: [
//             _buildStatCard('Uploaded', result.uploaded, Colors.green.withOpacity(0.2), Colors.green),
//             const SizedBox(width: 12),
//             _buildStatCard('Skipped', result.skipped, Colors.orange.withOpacity(0.2), Colors.orange),
//             const SizedBox(width: 12),
//             _buildStatCard('Failed', result.failed, Colors.red.withOpacity(0.2), Colors.red),
//           ],
//         ),
//       ],
//     );
//   }
//
//   Widget _buildStatCard(String label, int count, Color bgColor, Color accentColor) {
//     return Expanded(
//       child: Container(
//         decoration: BoxDecoration(
//           color: bgColor,
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: accentColor.withOpacity(0.5)),
//         ),
//         padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//         child: Column(
//           children: [
//             Text(count.toString(), style: TextStyle(color: accentColor, fontSize: 24, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 4),
//             Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildErrorsList(List<String> errors) {
//     return Container(
//       decoration: BoxDecoration(
//         color: const Color(0xFF1B263B),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.red.withOpacity(0.3)),
//       ),
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text('Sync errors (${errors.length})',
//               style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
//           const SizedBox(height: 8),
//           for (final e in errors)
//             Padding(
//               padding: const EdgeInsets.only(bottom: 6),
//               child: Text(e, style: const TextStyle(color: Colors.white54, fontSize: 12)),
//             ),
//         ],
//       ),
//     );
//   }
// }
//

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../services/sales_import_service.dart';

class SalesUploadPage extends StatefulWidget {
  const SalesUploadPage({super.key});

  @override
  State<SalesUploadPage> createState() => _SalesUploadPageState();
}

/// Kept only so old call sites that reference `SalesUploadWithoutValidate`
/// still compile — it now renders the exact same page.
class SalesUploadWithoutValidate extends StatelessWidget {
  const SalesUploadWithoutValidate({super.key});

  @override
  Widget build(BuildContext context) => const SalesUploadPage();
}

class _SalesUploadPageState extends State<SalesUploadPage> {
  bool _syncing = false;
  ApiSyncResult? _lastResult;
  DateTime? _lastSyncAt;
  String? _lastError;

  SalesImportService get _service => context.read<Datafeed>().salesImport;

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _syncFromApi() async {
    if (_syncing) return;

    print('[UI] Sync button pressed');

    final datafeed = context.read<Datafeed>();
    try {
      if (datafeed.companyid.isEmpty || datafeed.branchid.isEmpty) {
        print('[UI] Missing companyid/branchid — calling getdata()');
        await datafeed.getdata();
      }
    } catch (e, st) {
      print('[UI] datafeed.getdata() failed: $e');
      print(st);
      _snack('Could not load account info: $e', Colors.red);
      return;
    }

    if (!mounted) return;
    if (datafeed.companyid.isEmpty) {
      print('[UI] companyid still empty after getdata()');
      _snack('No company context found. Please log in again.', Colors.red);
      return;
    }
    if (datafeed.branchid.isEmpty) {
      print('[UI] branchid still empty after getdata()');
      _snack('No branch context found for your account. Please log in again.', Colors.red);
      return;
    }

    setState(() {
      _syncing = true;
      _lastError = null;
    });

    try {
      print('[UI] Calling syncFromExternalApi...');
      final result = await _service.syncFromExternalApi(
        datafeed: datafeed,
        companyId: datafeed.companyid,
        companyName: datafeed.company,
        staffPosition: datafeed.staffPosition.toString(),
        staffName: datafeed.staff,
        staffEmail: datafeed.staffemail,
        defaultBranchId: datafeed.branchid,
      );

      print('[UI] Sync succeeded: $result');

      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _lastSyncAt = DateTime.now();
      });

      if (result.uploaded == 0 && result.fetched == 0) {
        _snack('No sales returned by the POS API.', Colors.teal);
      } else if (result.uploaded == 0 && result.skipped > 0) {
        _snack('Nothing new — ${result.skipped} sale(s) already synced.', Colors.teal);
      } else if (result.failed > 0) {
        _snack(
          'Synced ${result.uploaded} sale(s), ${result.failed} failed, ${result.skipped} already synced.',
          Colors.orange,
        );
      } else {
        _snack(
          'Synced ${result.uploaded} sale(s) from the POS API (${result.skipped} already synced, skipped).',
          Colors.green,
        );
      }
    } catch (e, st) {
      print('[UI] Sync FAILED: $e');
      print(st);
      if (!mounted) return;
      setState(() => _lastError = e.toString());
      _snack('POS API sync failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text('Sync Sales from POS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildApiSyncSection(),
                  if (_lastResult != null) ...[
                    const SizedBox(height: 24),
                    _buildResultSummary(),
                  ],
                  if (_lastResult?.errors.isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    _buildErrorsList(_lastResult!.errors),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiSyncSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF22304A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync, color: _syncing ? Colors.lightBlue : Colors.white70, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync from POS API',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pulls unsynced sales (sync_status "0") from the connected POS, uploads the new ones, '
                          'and reports the ids back so the POS can mark them synced. Already-synced sales are '
                          'skipped automatically.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _syncing ? Colors.grey : Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: _syncing ? null : _syncFromApi,
              icon: _syncing
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
                  : const Icon(Icons.cloud_sync),
              label: Text(_syncing ? 'Syncing…' : 'Sync Now', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          if (_lastError != null) ...[
            const SizedBox(height: 12),
            Text(_lastError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildResultSummary() {
    final result = _lastResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_lastSyncAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Last sync at ${_lastSyncAt!.toLocal().toString().split('.').first} — ${result.fetched} row(s) fetched from the API.',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        Row(
          children: [
            _buildStatCard('Uploaded', result.uploaded, Colors.green.withOpacity(0.2), Colors.green),
            const SizedBox(width: 12),
            _buildStatCard('Skipped', result.skipped, Colors.orange.withOpacity(0.2), Colors.orange),
            const SizedBox(width: 12),
            _buildStatCard('Failed', result.failed, Colors.red.withOpacity(0.2), Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int count, Color bgColor, Color accentColor) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Text(count.toString(), style: TextStyle(color: accentColor, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorsList(List<String> errors) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sync errors (${errors.length})',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 8),
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(e, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

