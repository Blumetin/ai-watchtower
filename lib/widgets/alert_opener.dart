import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/alert.dart';
import '../data/alert_repository.dart';
import '../screens/alert_detail_screen.dart';

class AlertOpener extends InheritedWidget {
  final void Function(Alert alert, ValueListenable<AlertFeed?>? feed) open;

  final void Function(
    List<Alert> alerts,
    ValueListenable<AlertFeed?>? feed,
    bool Function(Alert)? filter,
  )?
  openGroup;
  const AlertOpener({
    super.key,
    required this.open,
    this.openGroup,
    required super.child,
  });

  static bool openGroupIn(
    BuildContext context,
    List<Alert> alerts,
    ValueListenable<AlertFeed?>? feed,
    bool Function(Alert)? filter,
  ) {
    final g = context.getInheritedWidgetOfExactType<AlertOpener>()?.openGroup;
    if (g == null) return false;
    g(alerts, feed, filter);
    return true;
  }

  static void openAlert(
    BuildContext context,
    Alert alert, [
    ValueListenable<AlertFeed?>? feed,
  ]) {
    final o = context.getInheritedWidgetOfExactType<AlertOpener>();
    if (o != null) return o.open(alert, feed);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertDetailScreen(alert: alert, feed: feed),
      ),
    );
  }

  @override
  bool updateShouldNotify(AlertOpener oldWidget) =>
      open != oldWidget.open || openGroup != oldWidget.openGroup;
}
