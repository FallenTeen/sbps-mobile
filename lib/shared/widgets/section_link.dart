import 'package:flutter/material.dart';

import 'section_header.dart';

SectionHeader sectionHeaderWithLink({
  required String title,
  required String actionLabel,
  required VoidCallback onAction,
  IconData? leadingIcon,
}) {
  return SectionHeader(
    title: title,
    leadingIcon: leadingIcon,
    padding: const EdgeInsets.only(bottom: 8),
    trailing: TextButton(
      onPressed: onAction,
      child: Text(actionLabel),
    ),
  );
}
