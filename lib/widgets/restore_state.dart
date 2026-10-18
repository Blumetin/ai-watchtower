import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../web/web_restore.dart';

class RestoreTabSaver extends StatefulWidget {
  final String id;
  final Widget child;
  const RestoreTabSaver({super.key, required this.id, required this.child});

  static int? take(String id, int length) {
    final v = WebRestore.take(id);
    return v is int && v >= 0 && v < length ? v : null;
  }

  @override
  State<RestoreTabSaver> createState() => _RestoreTabSaverState();
}

class _RestoreTabSaverState extends State<RestoreTabSaver> {
  late final Object? Function() _saver = _save;
  Object? _save() => DefaultTabController.maybeOf(context)?.index;

  @override
  void initState() {
    super.initState();
    WebRestore.register(widget.id, _saver);
  }

  @override
  void dispose() {
    WebRestore.unregister(widget.id, _saver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void scrollToRestored(
  ScrollController controller,
  double target, {
  required bool Function() alive,
  VoidCallback? onDone,
  VoidCallback? onNotReady,
  int frames = 12,
}) {
  void step(int left, double? lastMax) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!alive()) return;
      final ready =
          controller.hasClients && controller.position.hasContentDimensions;
      if (!ready) {
        left > 1 ? step(left - 1, lastMax) : (onNotReady ?? onDone)?.call();
        return;
      }
      final pos = controller.position;
      final max = pos.maxScrollExtent;
      if (lastMax != null && max <= lastMax && pos.pixels >= max - 1) {
        onDone?.call();
        return;
      }
      controller.jumpTo(target.clamp(0.0, math.max(0.0, max)));
      if (pos.pixels >= target - 1 || left <= 1) {
        onDone?.call();
        return;
      }
      step(left - 1, max);
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  step(frames, null);
}

class RestoreScroll {
  final String id;
  final ScrollController controller;
  double? _pending;
  bool _running = false;
  bool _disposed = false;
  late final Object? Function() _saver = _save;
  Object? _save() =>
      _pending ??
      (controller.hasClients && controller.position.hasPixels
          ? math.max(0.0, controller.offset)
          : null);

  RestoreScroll(this.id, this.controller) {
    final v = WebRestore.take(id);
    if (v is num && v.isFinite && v >= 0) _pending = v.toDouble();
    WebRestore.register(id, _saver);
  }

  void apply() {
    final o = _pending;
    if (o == null || _running) return;
    _running = true;
    scrollToRestored(
      controller,
      o,
      alive: () => !_disposed,
      onDone: () {
        _pending = null;
        _running = false;
      },
      onNotReady: () => _running = false,
    );
  }

  void dispose() {
    _disposed = true;
    WebRestore.unregister(id, _saver);
  }
}
