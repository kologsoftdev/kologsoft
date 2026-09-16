


import 'package:flutter/material.dart';

InputDecoration decorationInput(String label, {String? hint, String? prefix}) =>
    InputDecoration(
      labelText:  label,
      hintText:   hint,
      prefixText: prefix,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle:  const TextStyle(color: Colors.white30, fontSize: 12),
      filled:     true,
      fillColor:  const Color(0xFF22304A),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Colors.blue),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Colors.redAccent),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
