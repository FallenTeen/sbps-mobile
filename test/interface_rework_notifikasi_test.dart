import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/notifikasi/models/notification.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_screen.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';

void main() {
  test('categoryVisual has no literal hex colors', () {
    final source = File('lib/features/notifikasi/notifikasi_screen.dart')
        .readAsStringSync();
    final start = source.indexOf('CategoryVisual categoryVisual(');
    final end = source.indexOf('\n}', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final body = source.substring(start, end + 2);
    expect(body, isNot(contains('0xFF')));
    expect(source, contains("label: 'Belum dibaca'"));
    expect(source, contains(r'${c.label}'));
  });

  for (final entry in [
    MapEntry('light', AppTheme.lightTheme),
    MapEntry('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('category colors use ${entry.key} theme tokens', (tester) async {
      Map<NotificationCategory, CategoryVisual>? visuals;
      AppColors? colors;

      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: Builder(
            builder: (context) {
              colors = context.colors;
              visuals = {
                for (final category in NotificationCategory.values)
                  category: categoryVisual(context, category),
              };
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final palette = colors!;
      final resolved = visuals!;
      final allowed = <Color>[
        palette.warning,
        palette.success,
        palette.info,
        palette.error,
        palette.textTertiary,
      ];

      for (final category in NotificationCategory.values) {
        expect(
          allowed,
          contains(resolved[category]!.color),
          reason: '${category.label} must use a theme token',
        );
      }

      expect(
        resolved[NotificationCategory.approval]!.color,
        palette.warning,
      );
      expect(resolved[NotificationCategory.servis]!.color, palette.info);
      expect(resolved[NotificationCategory.stok]!.color, palette.info);
      expect(resolved[NotificationCategory.produksi]!.color, palette.error);
      expect(resolved[NotificationCategory.presensi]!.color, palette.success);
      expect(resolved[NotificationCategory.formulir]!.color, palette.success);
      expect(
        resolved[NotificationCategory.sistem]!.color,
        palette.textTertiary,
      );
      expect(
        resolved[NotificationCategory.produksi]!.color,
        isNot(palette.primary),
      );
    });
  }
}
