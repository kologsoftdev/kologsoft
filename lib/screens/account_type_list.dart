import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/models/account_type_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import 'account_type_reg.dart';

class AccountTypeList extends StatelessWidget {
  final String accountClass;
  const AccountTypeList({super.key, required this.accountClass});

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final query = value.db.collection('accounts').where('companyId', isEqualTo: value.companyid).where('accountClass', isEqualTo: accountClass).orderBy('name');
        return Scaffold(
          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            title: Text('$accountClass Accounts'),
            backgroundColor: const Color(0xFF0D1A26),
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blue,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountTypeReg(
                    account: AccountTypeModel(accountClass: accountClass),
                  ),
                ),
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
                    'Failed to load accounts: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }

              final accounts = snapshot.data?.docs ?? const [];
              if (accounts.isEmpty) {
                return const Center(
                  child: Text(
                    'No accounts found for this class.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final doc = accounts[index];
                  final data = doc.data();
                  final account = AccountTypeModel.fromJson(data);
                  final details = [
                    account.accountClass,
                    account.accountClassType,
                    account.subAccount,
                  ].where((value) => value.trim().isNotEmpty).toList();

                  return Card(
                    color: const Color(0xFF182232),
                    child: ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white70,
                      ),
                      title: Text(
                        account.name,
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
                            builder: (_) => AccountTypeReg(account: account),
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
