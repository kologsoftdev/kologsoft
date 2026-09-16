import 'package:flutter/material.dart';

void snackMsg(
    BuildContext context,
    String msg,
    Color color, {
      Duration dur = const Duration(seconds: 2),
    }) {
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: TextStyle(
        color: theme.colorScheme.onPrimary,
      ),),
      backgroundColor: color,
      duration: dur,
    ),
  );
}