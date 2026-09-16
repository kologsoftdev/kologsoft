import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class Constants {
  static const String defaultLanguage = "en";
  static const backgroundColor = 0xFFFFFFFF;
  static const formbackgroundColor = 0xFF0000FF;
  static const appbarcolor = 0xFF00FF00;
  static const buttoncolor = 0xFFFF0000;
  static const bgDark = Color(0xFF101624);
  static const bgCard = Color(0xFF1A2036);
  static const bgInput = Color(0xFF101624);
  static const textPrimary = Color(0xFFE8EDF5);
  static const textSecondary = Color(0xFF8892B0);
  static const textMuted = Color(0xFF4A5370);
  static const borderColor = Color(0xFF2A3350);
  static const amber = Color(0xFFD29922);
  static const amberBg = Color(0xFF2D1B00);
  static const amberFill = Color(0xFFE8A33D);
  static const green = Color(0xFF3FB950);
  static const greenBg = Color(0xFF0D2D1A);
  static const accent = Color(0xFF58A6FF);


}
class LoadingDialog {
  static BuildContext? _dialogContext;

  static Future<void> show(
      BuildContext context, {
        String message = "Please wait...",
      }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _dialogContext = dialogContext;

        return PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(message),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void hide() {
    if (_dialogContext != null) {
      Navigator.of(_dialogContext!).pop();
      _dialogContext = null;
    }
  }
}

 validateAvailableBalance({
  context,
  required String itemId,
  required String itemName,
  required String branchId,
  required num requiredPieces,

}) async {
  final value= Provider.of<Datafeed>(context, listen: false);

  final available = await value.fetchItemCurrentBalance(
    itemId: itemId,
    selectedBranch: branchId,
  );

  if (available < requiredPieces) {
    throw Exception(
      '$itemName\n'
          'Available: ${available.toInt()} pcs\n'
          'Required: ${requiredPieces.toInt()} pcs',
    );
  }
}