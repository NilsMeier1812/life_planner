import 'package:flutter/material.dart';

/// Parses a hex color string ('#RRGGBB') into a Color object.
///
/// Returns Colors.grey if parsing fails.
Color parseColor(String hexString) {
  try {
    final hexCode = hexString.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  } catch (e) {
    debugPrint('Could not parse color: $hexString. Error: $e');
    return Colors.grey;
  }
}
