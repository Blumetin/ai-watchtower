import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/push_prefs.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../web/site_chrome.dart' show sitePage;
import '../widgets/call.dart';
import 'about_screen.dart';
import 'push_settings_screen.dart';
import 'quake_screen.dart' show CwaAttribution;

class SettingsScreen extends StatelessWidget {
  final PushPrefsStore pushPrefs;
  const SettingsScreen({super.key, required this.pushPrefs});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    Widget tile(IconData icon, String title, Widget page) => ListTile(
      minTileHeight: AppLayout.touchTarget,
      leading: Icon(icon),
      title: Text(title, style: text.titleMedium),
      trailing: const Icon(Symbols.chevron_right_rounded),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(t.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          tile(
            Symbols.notifications_rounded,
            t.pushTitle,
            PushSettingsScreen(store: pushPrefs),
          ),
          const Divider(),
          tile(Symbols.info_rounded, t.aboutUsTitle, const AboutScreen()),
          const Divider(),
          tile(
            Symbols.source_rounded,
            t.dataSourcesTitle,
            const DataSourcesScreen(),
          ),
          const Divider(),
          tile(
            Symbols.privacy_tip_rounded,
            t.privacyTitle,
            const PrivacyScreen(),
          ),
          const Divider(),
          tile(
            Symbols.description_rounded,
            t.licensesTitle,
            LicensePage(applicationName: t.appTitle),
          ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  final bool embedded;
  const PrivacyScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final items = [
      t.privacyQa,
      t.privacyNoStore,
      t.privacyIpHash,
      t.privacyNoLogin,
      t.privacyPushLocal,
      t.privacyMapTiles,
      t.privacyDataSource,
    ];
    return sitePage(
      embedded: embedded,
      title: t.privacyTitle,
      body: ListView(
        padding: AppLayout.pagePadding,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, right: 12),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(child: Text(item, style: text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class DataSourcesScreen extends StatelessWidget {
  final bool embedded;
  const DataSourcesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final items = [
      (
        Symbols.campaign_rounded,
        t.srcAlertsTitle,
        t.srcAlertsBody,
        'https://alerts.ncdr.nat.gov.tw/',
      ),
      (
        Symbols.earthquake_rounded,
        t.srcQuakesTitle,
        t.srcQuakesBody(t.datasetSignificant, t.datasetLocal),
        'https://opendata.cwa.gov.tw/',
      ),
      (
        Symbols.map_rounded,
        t.srcBoundaryTitle,
        t.srcBoundaryBody,
        'https://data.gov.tw/dataset/7442',
      ),
      (
        Symbols.history_rounded,
        t.srcHistoryTitle,
        t.srcHistoryBody,
        'https://earthquake.usgs.gov/earthquakes/search/',
      ),
      (
        Symbols.layers_rounded,
        t.srcBasemapTitle,
        t.srcBasemapBody,
        'https://policies.google.com/privacy',
      ),
    ];
    return sitePage(
      embedded: embedded,
      title: t.dataSourcesTitle,
      body: ListView(
        padding: AppLayout.pagePadding,
        children: [
          for (final (icon, title, body, url) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title, style: text.titleMedium),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(body, style: text.bodyMedium),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size(0, AppLayout.touchTarget),
                    ),
                    onPressed: () => openExternal(context, url),
                    icon: const Icon(Symbols.open_in_new_rounded, size: 18),
                    label: Text(
                      t.openSourcePage,
                      semanticsLabel: t.openSourcePageFor(title),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, AppLayout.touchTarget),
            ),
            onPressed: () => openExternal(context, CwaAttribution.licenseUrl),
            icon: const Icon(Symbols.open_in_new_rounded, size: 18),
            label: Text(t.openDataLicense),
          ),
        ],
      ),
    );
  }
}
