import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kShowFirstAid = false;

class PrepSection {
  final String id;
  final String title;
  final List<PrepBlock> blocks;
  const PrepSection(this.id, this.title, this.blocks);

  factory PrepSection.fromJson(Map<String, dynamic> m) =>
      PrepSection(m['id'] as String, m['title'] as String, [
        for (final b in m['blocks'] as List)
          PrepBlock.fromJson(b as Map<String, dynamic>),
      ]);
}

class PrepBlock {
  final String id;
  final List<PrepGroup> groups;
  final String source;
  final List<String> links;
  const PrepBlock(this.id, this.groups, this.source, this.links);

  factory PrepBlock.fromJson(Map<String, dynamic> m) => PrepBlock(
    m['id'] as String,
    [
      for (final g in m['groups'] as List)
        PrepGroup.fromJson(g as Map<String, dynamic>),
    ],
    m['source'] as String? ?? '',
    [...?(m['links'] as List?)?.cast<String>()],
  );
}

class PrepGroup {
  final String title;
  final String note;
  final List<String> items;
  final bool numbered;

  final List<String> pending;
  const PrepGroup(
    this.title,
    this.note,
    this.items,
    this.numbered,
    this.pending,
  );

  factory PrepGroup.fromJson(Map<String, dynamic> m) => PrepGroup(
    m['title'] as String? ?? '',
    m['note'] as String? ?? '',
    [...?(m['items'] as List?)?.cast<String>()],
    m['numbered'] as bool? ?? false,
    [...?(m['pending'] as List?)?.cast<String>()],
  );
}

Future<List<PrepSection>> loadPrepSections(String lang) async {
  final l = const {'zh', 'en', 'ja'}.contains(lang) ? lang : 'en';
  final main = jsonDecode(
    await rootBundle.loadString('assets/content/prep_$l.json'),
  ) as Map<String, dynamic>;
  return [
    for (final s in main['sections'] as List)
      PrepSection.fromJson(s as Map<String, dynamic>),
    if (kShowFirstAid)
      PrepSection.fromJson(
        (jsonDecode(
              await rootBundle.loadString('assets/content/first_aid_$l.json'),
            ) as Map<String, dynamic>)['section']
            as Map<String, dynamic>,
      ),
  ];
}

class PrepChecklistStore {
  static const _key = 'prep_checklist_v1';

  static String key(int group, int item) => '$group:$item';

  Future<Set<String>> load() async {
    final sp = await SharedPreferences.getInstance();
    return {
      for (final v in sp.getStringList(_key) ?? const <String>[])
        v.contains(':') ? v : '1:$v',
    };
  }

  Future<void> save(Set<String> checked) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_key, [...checked]);
  }
}
