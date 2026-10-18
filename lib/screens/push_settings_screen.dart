import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/push_prefs.dart';
import '../data/push_service.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

class PushSettingsScreen extends StatefulWidget {
  final PushPrefsStore store;
  const PushSettingsScreen({super.key, required this.store});

  @override
  State<PushSettingsScreen> createState() => _PushSettingsScreenState();
}

class _PushSettingsScreenState extends State<PushSettingsScreen> {
  PushPrefs? _prefs;
  bool _loadFailed = false;

  bool? _permitted;

  @override
  void initState() {
    super.initState();
    _load();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final ok = await PushService.instance.permission();
    if (mounted) setState(() => _permitted = ok);
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    setState(() {
      _loadFailed = false;
      _prefs = null;
    });
    try {
      final p = await widget.store.load();
      if (mounted && gen == _loadGen) setState(() => _prefs = p);
    } catch (_) {
      if (mounted && gen == _loadGen) setState(() => _loadFailed = true);
    }
  }

  int _loadGen = 0;

  bool _saving = false;

  Future<void> _update(PushPrefs next) async {
    if (_saving) return;
    final confirmed = _prefs;
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      _prefs = next;
      _saving = true;
    });
    try {
      if (next.counties.isNotEmpty) {
        final ok = await PushService.instance.requestPermission(
          userAction: true,
        );
        if (mounted) setState(() => _permitted = ok);
      }
      await widget.store.save(next);
      unawaited(PushService.instance.sync(next, lang));
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs = confirmed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.saveFailed)),
      );
      final gen = ++_loadGen;
      try {
        final actual = await widget.store.load();
        if (mounted && gen == _loadGen) setState(() => _prefs = actual);
      } catch (_) {
        if (mounted && gen == _loadGen) {
          setState(() {
            _loadFailed = true;
            _prefs = null;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final p = _prefs;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final notice = ios
        ? t.pushPreviewNotice
        : (PushService.instance.enabled ? null : t.pushServiceUnavailable);
    final permissionOff =
        !ios && PushService.instance.enabled && _permitted == false;

    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: Text(t.pushTitle)),
        body: Padding(
          padding: AppLayout.pagePadding,
          child: Text(t.pushWebUnavailable, style: text.bodyMedium),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(t.pushTitle)),
      body: _loadFailed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.settingsLoadFailed, style: text.bodyMedium),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: Text(t.retry)),
                ],
              ),
            )
          : p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppLayout.pagePadding,
              children: [
                if (notice != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppLayout.radius),
                    ),
                    child: Text(
                      notice,
                      style: text.bodyMedium!.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (permissionOff)
                  Text(
                    t.pushPermissionOff,
                    style: text.bodyMedium!.copyWith(color: AppColors.attention),
                  ),
                if (notice != null || permissionOff)
                  const SizedBox(height: 24),
                Text(t.pushLevels, style: text.headlineSmall),
                const SizedBox(height: 8),
                Text(t.pushScopeNote, style: text.bodySmall),
                const SizedBox(height: 4),
                Text(t.pushCooldownNote, style: text.bodySmall),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Symbols.info_rounded),
                    ),
                    Expanded(
                      child: Text(t.pushExtremeAlwaysOn, style: text.bodySmall),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _LevelSwitch(
                  title: t.severityCritical,
                  subtitle: t.pushCriticalDesc,
                  color: severityColor('critical'),
                  value: p.critical,
                  onChanged: _saving
                      ? null
                      : (v) => _update(p.copyWith(critical: v)),
                ),
                if (!p.critical)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      t.pushCriticalOffWarning,
                      style: text.bodySmall!.copyWith(
                        color: AppColors.attention,
                      ),
                    ),
                  ),
                if (kDebugMode)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('端對端測試（僅除錯版）'),
                    subtitle: const Text('改訂 test_ 主題，不訂正式主題'),
                    value: p.test,
                    onChanged: _saving
                        ? null
                        : (v) => _update(p.copyWith(test: v)),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(t.pushCounties, style: text.headlineSmall),
                    ),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => _update(
                              p.copyWith(
                                counties: p.counties.length == counties.length
                                    ? {}
                                    : counties.keys.toSet(),
                              ),
                            ),
                      child: Text(
                        p.counties.length == counties.length
                            ? t.pushClearAll
                            : t.pushSelectAll,
                      ),
                    ),
                  ],
                ),
                Text(
                  t.pushCountiesHint(p.counties.length),
                  style: text.bodySmall!.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final code in counties.keys)
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: AppLayout.touchTarget,
                          minWidth: AppLayout.touchTarget,
                        ),
                        child: FilterChip(
                          label: Text(countyName(code, lang)),
                          selected: p.counties.contains(code),
                          showCheckmark: true,
                          labelStyle: text.labelMedium,
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          onSelected: _saving
                              ? null
                              : (on) {
                                  final next = {...p.counties};
                                  on ? next.add(code) : next.remove(code);
                                  _update(p.copyWith(counties: next));
                                },
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _LevelSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _LevelSwitch({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: AppLayout.touchTarget,
      secondary: Container(
        width: AppLayout.accentBarWidth,
        height: 40,
        color: color,
      ),
      title: Text(title, style: text.titleMedium),
      subtitle: Text(subtitle, style: text.bodySmall),
      value: value,
      onChanged: onChanged,
    );
  }
}
