import 'package:flutter/material.dart';

class SnackMessage {
  SnackMessage._();

  static void show(String message, Color color, BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}
