import 'package:flutter/material.dart';

class FeedbackService {
  FeedbackService._();
  static final _queue = <_ToastEntry>[];
  static const int _maxVisible = 3;

  static void success(BuildContext context, String message, {Duration duration = const Duration(seconds: 3), VoidCallback? action}) {
    _show(context, message, Icons.check_circle, Colors.green, duration, action);
  }

  static void error(BuildContext context, String message, {Duration duration = const Duration(seconds: 4), VoidCallback? action}) {
    _show(context, message, Icons.error, Colors.red, duration, action);
  }

  static void warning(BuildContext context, String message, {Duration duration = const Duration(seconds: 3), VoidCallback? action}) {
    _show(context, message, Icons.warning, Colors.orange, duration, action);
  }

  static void info(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    _show(context, message, Icons.info, Colors.blue, duration, null);
  }

  static void _show(BuildContext context, String message, IconData icon, Color color, Duration duration, VoidCallback? action) {
    if (_queue.length >= _maxVisible) {
      _queue.removeAt(0);
    }
    final entry = _ToastEntry(message: message, icon: icon, color: color, duration: duration, action: action);
    _queue.add(entry);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: duration,
        action: action == null
            ? null
            : SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: action),
      ),
    );
    Future.delayed(duration, () => _queue.remove(entry));
  }
}

class _ToastEntry {
  final String message;
  final IconData icon;
  final Color color;
  final Duration duration;
  final VoidCallback? action;
  _ToastEntry({required this.message, required this.icon, required this.color, required this.duration, this.action});
}
