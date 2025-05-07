// lib/notifications/overlay_notification.dart

import 'package:flutter/material.dart';
import 'dart:async';

/// POPUP NOTIFICATION
class OverlayNotification {
  static OverlayEntry? _overlayEntry;
  static Timer? _dismissTimer;
  static bool _isVisible = false;

  static bool get isVisible => _isVisible;

  /// SHOW NOTIFICATION
  ///
  /// [context]    — context
  /// [title]      — title
  /// [message]    — message
  /// [duration]   — duration
  /// [onConfirm]  — onConfirm
  /// [onCancel]   — onCancel
  /// [onExit]     — onExit
  /// [icon]       — icon
  /// [persistent] — persistent
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    VoidCallback? onExit,
    Widget? icon,
    bool persistent = false,
  }) {
    // Close previous, if open
    if (_isVisible) dismiss();
    _isVisible = true;

    _overlayEntry = OverlayEntry(builder: (ctx) {
      return Stack(
        children: [
          // DARK FILTER
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        icon!,
                        const SizedBox(height: 12),
                      ],
                      Text(title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(height: 10),
                      Text(message,
                          style: const TextStyle(fontSize: 16, color: Colors.black87), textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (onCancel != null)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[200],
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                dismiss();
                                onCancel();
                              },
                              child: const Text('გაუქმება'),
                            ),
                          if (onConfirm != null)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                dismiss();
                                onConfirm();
                              },
                              child: const Text('პარკირება'),
                            ),
                        ],
                      ),
                      if (onExit != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.black38, size: 22),
                            onPressed: () {
                              dismiss();
                              onExit();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });

    Overlay.of(context).insert(_overlayEntry!);
    if (!persistent) {
      _dismissTimer = Timer(duration, dismiss);
    }
  }

  /// CLOSE NOTIFICATION
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isVisible = false;
  }
}
