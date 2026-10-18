import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/prep_content.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../web/site_chrome.dart' show SitePageTitle, sitePage;
import '../widgets/call.dart';
import '../widgets/restore_state.dart';

class PrepScreen extends StatefulWidget {
  final bool embedded;
  const PrepScreen({super.key, this.embedded = false});

  @override
  State<PrepScreen> createState() => _PrepScreenState();
}

class _PrepScreenState extends State<PrepScreen> {
  static const _restoreTabId = 'prep.tab';

  Future<List<PrepSection>>? _sections;
  String? _lang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    if (lang != _lang) {
      _lang = lang;
      _sections = loadPrepSections(lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return FutureBuilder(
      future: _sections,
      builder: (context, snap) {
        final sections = snap.data;
        if (sections == null) {
          return sitePage(
            embedded: widget.embedded,
            title: t.prepTitle,
            body: Center(
              child: snap.hasError
                  ? Text(t.loadFailed)
                  : const CircularProgressIndicator(),
            ),
          );
        }
        final views = TabBarView(
          children: [
            for (final s in sections)
              s.id == 'bag' ? _BagTab(section: s) : _SectionList(section: s),
          ],
        );
        if (widget.embedded) {
          return DefaultTabController(
            length: sections.length,
            initialIndex:
                RestoreTabSaver.take(_restoreTabId, sections.length) ?? 0,
            child: RestoreTabSaver(
              id: _restoreTabId,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SitePageTitle(t.prepTitle),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.onSurfaceVariant,
                    indicatorColor: AppColors.primary,
                    labelStyle: Theme.of(context).textTheme.titleMedium,
                    tabs: [
                      for (final s in sections)
                        Tab(height: AppLayout.touchTarget, text: s.title),
                    ],
                  ),
                  Expanded(child: views),
                ],
              ),
            ),
          );
        }
        return DefaultTabController(
          length: sections.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(t.prepTitle),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                labelStyle: Theme.of(context).textTheme.titleMedium,
                tabs: [
                  for (final s in sections)
                    Tab(height: AppLayout.touchTarget, text: s.title),
                ],
              ),
            ),
            body: views,
          ),
        );
      },
    );
  }
}

class _BagTab extends StatefulWidget {
  final PrepSection section;
  const _BagTab({required this.section});

  @override
  State<_BagTab> createState() => _BagTabState();
}

class _BagTabState extends State<_BagTab> with AutomaticKeepAliveClientMixin {
  final _store = PrepChecklistStore();
  Set<String> _checked = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _store
        .load()
        .then((v) {
          if (mounted) setState(() => _checked = v);
        })
        .catchError((Object _) {});
  }

  void _toggle(String k, bool on) {
    setState(() => on ? _checked.add(k) : _checked.remove(k));
    _store.save({..._checked}).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _SectionList(
      section: widget.section,
      checklist: (group, index) => group == 1 || group == 2
          ? _ChecklistState(
              checked: _checked.contains(PrepChecklistStore.key(group, index)),
              onChanged: (v) =>
                  _toggle(PrepChecklistStore.key(group, index), v),
            )
          : null,
    );
  }
}

class _ChecklistState {
  final bool checked;
  final ValueChanged<bool> onChanged;
  const _ChecklistState({required this.checked, required this.onChanged});
}

class _SectionList extends StatelessWidget {
  final PrepSection section;

  final _ChecklistState? Function(int group, int index)? checklist;
  const _SectionList({required this.section, this.checklist});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    var groupIndex = 0;
    return ListView(
      padding: AppLayout.pagePadding,
      children: [
        for (final block in section.blocks) ...[
          for (final g in block.groups)
            _Group(
              group: g,
              index: groupIndex++,
              checklist: checklist,
              text: text,
            ),
          _Source(block: block),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final PrepGroup group;
  final int index;
  final _ChecklistState? Function(int group, int index)? checklist;
  final TextTheme text;
  const _Group({
    required this.group,
    required this.index,
    required this.checklist,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(group.title, style: text.headlineMedium),
          ),
          if (group.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              group.note,
              style: text.bodySmall!.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final (i, item) in group.items.indexed)
            switch (checklist?.call(index, i)) {
              final c? => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                minTileHeight: AppLayout.touchTarget,
                value: c.checked,
                onChanged: (v) => c.onChanged(v ?? false),
                title: Text(item, style: text.bodyMedium),
              ),
              null => MergeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          group.numbered ? '${i + 1}.' : '•',
                          style: text.bodyMedium,
                        ),
                      ),
                      Expanded(child: Text(item, style: text.bodyMedium)),
                    ],
                  ),
                ),
              ),
            },
          for (final p in group.pending)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                p,
                style: text.bodySmall!.copyWith(color: AppColors.attention),
              ),
            ),
        ],
      ),
    );
  }
}

class _Source extends StatelessWidget {
  final PrepBlock block;
  const _Source({required this.block});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          block.source,
          style: text.bodySmall!.copyWith(color: AppColors.onSurfaceVariant),
        ),
        for (final url in block.links)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, AppLayout.touchTarget),
            ),
            onPressed: () => openExternal(context, url),
            icon: const Icon(Symbols.open_in_new_rounded, size: 18),
            label: Text(
              Uri.parse(url).host,
              semanticsLabel: t.openSourcePageFor(Uri.parse(url).host),
            ),
          ),
      ],
    );
  }
}
