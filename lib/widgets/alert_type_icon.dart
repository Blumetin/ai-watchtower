import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme.dart';

class AlertTypeIcon extends StatelessWidget {
  final String group;
  final String rawCategory;
  final double size;
  final Color color;
  const AlertTypeIcon({
    super.key,
    required this.group,
    required this.rawCategory,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Icon(
    rawCategory.contains('海洋污染')
        ? Symbols.tsunami_rounded
        : groupIcon(group),
    size: size,
    color: color,
  );
}
