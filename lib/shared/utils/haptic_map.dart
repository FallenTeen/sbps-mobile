import 'package:flutter/services.dart';

enum HapticType { light, medium, heavy, selection, success }

void triggerHaptic(HapticType type) {
  switch (type) {
    case HapticType.light:
      HapticFeedback.lightImpact();
      break;
    case HapticType.medium:
      HapticFeedback.mediumImpact();
      break;
    case HapticType.heavy:
      HapticFeedback.heavyImpact();
      break;
    case HapticType.selection:
      HapticFeedback.selectionClick();
      break;
    case HapticType.success:
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 80), HapticFeedback.lightImpact);
      Future.delayed(const Duration(milliseconds: 200), HapticFeedback.mediumImpact);
      break;
  }
}
