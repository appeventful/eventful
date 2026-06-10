import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class PlatformHelper {
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get kIsWeb => identical(0, 0.0); // Simple web check

  static void hapticFeedback() {
    if (isIOS) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.vibrate();
    }
  }

  static void successHaptic() {
    if (isIOS) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.vibrate();
    }
  }

  static Future<T?> showAdaptiveDialog<T>({
    required BuildContext context,
    required String title,
    required String content,
    String? cancelText,
    required String confirmText,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    if (isIOS) {
      return showCupertinoDialog<T>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            if (cancelText != null)
              CupertinoDialogAction(
                child: Text(cancelText),
                onPressed: () => Navigator.pop(context),
              ),
            CupertinoDialogAction(
              isDestructiveAction: isDestructive,
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              child: Text(confirmText),
            ),
          ],
        ),
      );
    } else {
      return showDialog<T>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            if (cancelText != null)
              TextButton(
                child: Text(cancelText),
                onPressed: () => Navigator.pop(context),
              ),
            ElevatedButton(
              style: isDestructive 
                  ? ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white)
                  : null,
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              child: Text(confirmText),
            ),
          ],
        ),
      );
    }
  }
}
