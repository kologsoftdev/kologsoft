import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/models/sub_account_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import 'sub_account_form.dart';

class SubAccountView extends StatelessWidget {
  const SubAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final query = FirebaseFirestore.instance
            .collection('sub_accounts')
            .where('companyId', isEqualTo: value.companyid)
            .orderBy('accountClass')
            .orderBy('accountClassType')
            .orderBy('name');

        return Scaffold(
          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            title: const Text('SUB ACCOUNTS'),
            backgroundColor: const Color(0xFF0D1A26),
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blue,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubAccountForm()),
              );
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load sub accounts: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }

              final subAccounts = snapshot.data?.docs ?? const [];
              if (subAccounts.isEmpty) {
                return const Center(
                  child: Text(
                    'No sub accounts found.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: subAccounts.length,
                itemBuilder: (context, index) {
                  final doc = subAccounts[index];
                  final data = doc.data();
                  final subAccount = SubAccountModel.fromJson(data);

                  final details = [
                    subAccount.accountClass,
                    subAccount.accountClassType,
                  ].where((value) => value.trim().isNotEmpty).toList();

                  return Card(
                    color: const Color(0xFF182232),
                    child: ListTile(
                      leading: const Icon(
                        Icons.category,
                        color: Colors.white70,
                      ),
                      title: Text(
                        subAccount.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        details.join(' • '),
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: const Icon(Icons.edit, color: Colors.white54),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SubAccountForm(existingAccount: subAccount),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
