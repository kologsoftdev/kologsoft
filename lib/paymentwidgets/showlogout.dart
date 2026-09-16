import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

class LogoutDialog {
  static Future<void> show(BuildContext parentcontext) {
    final datafeed =Provider.of<Datafeed>(parentcontext, listen: false);

    return  showDialog(
      context: parentcontext,
      builder: (BuildContext context) {
        return AlertDialog(

          title: const Text('Logout',style: TextStyle(),),
          content: const Text('Are you sure you want to logout?',style: TextStyle(),),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',style: TextStyle(),),
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
}