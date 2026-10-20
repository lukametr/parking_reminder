// lib/notifications/overlay_notification.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Full-screen stay/leave dialog sized for small phones (stacked actions).
class OverlayNotification {
  static OverlayEntry? _overlayEntry;
  static Timer? _dismissTimer;
  static bool _isVisible = false;

  static bool get isVisible => _isVisible;

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
    String confirmLabel = 'პარკირება',
    String cancelLabel = 'არ ვჩერდები',
  }) {
    if (_isVisible) dismiss();
    _isVisible = true;

    _overlayEntry = OverlayEntry(builder: (BuildContext ctx) {
      final Size size = MediaQuery.sizeOf(ctx);
      final double maxW = size.width > 48 ? size.width - 24 : size.width;
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW, maxHeight: size.height * 0.85),
                child: Material(
                  color: Colors.transparent,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FutureBuilder<String?>(
                      future: fetchPopupBackgroundUrl(),
                      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
                        final String? imageUrl = snapshot.data;
                        return Stack(
                          children: [
                            if (imageUrl != null && imageUrl.isNotEmpty)
                              Positioned.fill(
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, Object _, StackTrace? __) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                            SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (icon != null) ...[
                                    icon,
                                    const SizedBox(height: 12),
                                  ],
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    message,
                                    style: const TextStyle(fontSize: 15, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 18),
                                  if (onConfirm != null)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () {
                                          dismiss();
                                          onConfirm();
                                        },
                                        child: Text(
                                          confirmLabel,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  if (onCancel != null) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[200],
                                          foregroundColor: Colors.black,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () {
                                          dismiss();
                                          onCancel();
                                        },
                                        child: Text(
                                          cancelLabel,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (onExit != null)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                                      onPressed: () {
                                        dismiss();
                                        onExit();
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
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

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isVisible = false;
  }

  static Future<String?> fetchPopupBackgroundUrl() async {
    final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(minutes: 5),
    ));
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getString('popup_background_url');
  }
}
