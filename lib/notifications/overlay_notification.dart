// lib/notifications/overlay_notification.dart

import 'package:flutter/material.dart';
import 'dart:async';

/// Класс для внутренних всплывающих уведомлений,
/// имитирующих поведение системных нотификаций
class OverlayNotification {
  static OverlayEntry? _overlayEntry;
  static Timer? _dismissTimer;
  static bool _isVisible = false;

  /// Показать уведомление
  ///
  /// [context]    — контекст
  /// [title]      — заголовок
  /// [message]    — текст
  /// [duration]   — время показа
  /// [onConfirm]  — колбэк по нажатию «подтвердить»
  /// [onCancel]   — колбэк по нажатию «отменить»
  /// [onExit]     — колбэк по нажатию на «закрыть» (крестик)
  /// [icon]       — иконка
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    VoidCallback? onExit,
    Widget? icon,
  }) {
    // Закрываем предыдущий, если открыт
    if (_isVisible) dismiss();
    _isVisible = true;

    final topPadding = MediaQuery.of(context).padding.top;
    _overlayEntry = OverlayEntry(builder: (ctx) {
      return Positioned(
        top: topPadding + 10,
        left: 10,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade700, Colors.blue.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    icon,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(message,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (onCancel != null)
                              TextButton(
                                onPressed: () {
                                  dismiss();
                                  onCancel();
                                },
                                child: const Text('გაუქმება',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            if (onConfirm != null)
                              TextButton(
                                onPressed: () {
                                  dismiss();
                                  onConfirm();
                                },
                                child: const Text('დადასტურება',
                                    style: TextStyle(color: Colors.white)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      dismiss();
                      if (onExit != null) onExit();
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.close, color: Colors.white70, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });

    Overlay.of(context).insert(_overlayEntry!);
    _dismissTimer = Timer(duration, dismiss);
  }

  /// Закрыть уведомление
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isVisible = false;
  }
}
