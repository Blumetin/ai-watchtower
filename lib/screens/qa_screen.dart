import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/qa_service.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../web/web_restore.dart';
import '../widgets/call.dart';
import '../widgets/crisis_lines.dart';
import '../widgets/report_dialog.dart';
import '../widgets/restore_state.dart';
import '../widgets/simple_markdown.dart';
import 'prep_screen.dart';
import 'settings_screen.dart' show PrivacyScreen;

class _Message {
  final GlobalKey key = GlobalKey();
  final bool fromUser;
  final String text;
  final List<QaSource> sources;
  final bool crisis;
  final bool prediction;

  final bool crisisCheck;

  final String? question;
  final String route;
  _Message(
    this.fromUser,
    this.text, {
    this.sources = const [],
    this.crisis = false,
    this.prediction = false,
    this.crisisCheck = false,
    this.question,
    this.route = '',
  });

  Map<String, Object?> toRestore() => {
    'u': fromUser,
    'x': text,
    's': [
      for (final s in sources) [s.name, s.url, s.title],
    ],
    'c': crisis,
    'p': prediction,
    'k': crisisCheck,
    'q': question,
  };

  static _Message? fromRestore(Object? e) {
    if (e is! Map) return null;
    final u = e['u'], x = e['x'], s = e['s'], c = e['c'], p = e['p'];
    final k = e['k'], q = e['q'];
    if (u is! bool || x is! String || s is! List || c is! bool) return null;
    if (p is! bool || k is! bool || (q != null && q is! String)) return null;
    if (x.length > 20000 || (q is String && q.length > 2000) || s.length > 30) {
      return null;
    }
    final sources = <QaSource>[];
    for (final v in s) {
      if (v is! List ||
          v.length != 3 ||
          v.any((f) => f is! String || f.length > 2000)) {
        return null;
      }
      final url = v[1] as String;
      if (!url.startsWith('https://')) continue;
      sources.add(QaSource(v[0] as String, url, v[2] as String));
    }
    return _Message(
      u,
      x,
      sources: sources,
      crisis: c,
      prediction: p,
      crisisCheck: k,
      question: q as String?,
    );
  }
}

class _QaSnapshot {
  final List<_Message> messages;
  final String? crisisCheckOf;
  final String draft;
  final double? offset;
  const _QaSnapshot(this.messages, this.crisisCheckOf, this.draft, this.offset);

  static _QaSnapshot? parse(Object? r) {
    if (r is! Map) return null;
    final list = r['m'], co = r['co'], d = r['d'], o = r['o'];
    if (list is! List || list.length > 200) return null;
    if (d is! String || d.length > 2000) return null;
    if (co != null && co is! String) return null;
    if (o != null && (o is! num || !o.isFinite || o < 0)) return null;
    final messages = <_Message>[];
    for (final e in list) {
      final m = _Message.fromRestore(e);
      if (m == null) return null;
      messages.add(m);
    }
    final last = messages.lastOrNull;
    if (last != null && !last.fromUser && last.crisisCheck) {
      final prev = messages.length >= 2 ? messages[messages.length - 2] : null;
      if (co is! String ||
          co.isEmpty ||
          last.question != co ||
          prev == null ||
          !prev.fromUser ||
          prev.text != co) {
        return null;
      }
    } else if (co != null) {
      return null;
    }
    return _QaSnapshot(messages, co as String?, d, (o as num?)?.toDouble());
  }

  Map<String, Object?> toRestore() => {
    'm': [for (final m in messages) m.toRestore()],
    'co': crisisCheckOf,
    'd': draft,
    'o': offset,
  };
}

class QaScreen extends StatefulWidget {
  final QaService service;
  const QaScreen({super.key, required this.service});

  static Map<String, Object?>? normalizeRestore(Object? r) =>
      _QaSnapshot.parse(r)?.toRestore();

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  final _outer = ScrollController();

  bool _composerHidden = false;
  final _inputFocus = FocusNode();

  bool _wasCramped = false;

  bool _crampedScrollPending = false;

  void _crampedToBottom() {
    if (!mounted || (_messages.lastOrNull?.crisis ?? false)) return;
    if (_outer.hasClients && _outer.position.hasContentDimensions) {
      _outer.jumpTo(_outer.position.maxScrollExtent);
    }
  }

  final _messages = <_Message>[];
  bool _sending = false;

  static const _restoreKey = 'qa';
  late final Object? Function() _saver = _snapshot;

  @override
  void initState() {
    super.initState();
    _inputFocus.addListener(_onFocusChanged);
    _restore(WebRestore.take(_restoreKey));
    _draftEmpty = _controller.text.isEmpty;
    _controller.addListener(_onDraftChanged);
    WebRestore.register(_restoreKey, _saver);
  }

  Object? _snapshot() {
    if (_messages.isEmpty && _controller.text.isEmpty) return null;
    final data = _QaSnapshot(
      _messages,
      _crisisCheckOf,
      _controller.text,
      _positioning ? _positionTarget : _currentOffset(),
    ).toRestore();
    if (_QaSnapshot.parse(data) == null) {
      throw StateError('qa restore snapshot rejected');
    }
    return data;
  }

  double? _currentOffset() {
    if (!_scroll.hasClients || !_scroll.position.hasPixels) return null;
    final pos = _scroll.position;
    final max = pos.hasContentDimensions
        ? pos.maxScrollExtent
        : double.infinity;
    return pos.pixels.clamp(0, max).toDouble();
  }

  bool _positioning = false;
  double? _positionTarget;
  Timer? _positionTimer;

  void _positioningDone({Duration after = Duration.zero}) {
    if (!mounted) return;
    _positionTimer?.cancel();
    void clear() {
      _positioning = false;
      _positionTarget = null;
      if (_crampedScrollPending) {
        _crampedScrollPending = false;
        WidgetsBinding.instance.addPostFrameCallback((_) => _crampedToBottom());
        WidgetsBinding.instance.scheduleFrame();
      }
    }

    after == Duration.zero ? clear() : _positionTimer = Timer(after, clear);
  }

  void _restore(Object? r) {
    final snap = _QaSnapshot.parse(r);
    if (snap == null) return;
    _messages.addAll(snap.messages);
    _crisisCheckOf = snap.crisisCheckOf;
    _controller.text = snap.draft;
    final o = snap.offset;
    final last = _messages.lastOrNull;
    _positioning = true;
    _positionTarget = o;
    _positioningDone(after: const Duration(seconds: 3));
    if (o != null) {
      scrollToRestored(
        _scroll,
        o,
        alive: () => mounted,
        onDone: _positioningDone,
      );
    } else {
      scrollToRestored(
        _scroll,
        double.infinity,
        alive: () => mounted,
        onDone: () {
          if (last != null && last.crisis && mounted) {
            _alignTop(last, onDone: _positioningDone);
          } else {
            _positioningDone();
          }
        },
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _outer.hasClients &&
          _outer.position.hasContentDimensions) {
        _outer.jumpTo(_outer.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    WebRestore.unregister(_restoreKey, _saver);
    _positionTimer?.cancel();
    _controller.removeListener(_onDraftChanged);
    _controller.dispose();
    _inputFocus.removeListener(_onFocusChanged);
    _inputFocus.dispose();
    _scroll.dispose();
    _outer.dispose();
    _crisisScroll.dispose();
    super.dispose();
  }

  bool _draftEmpty = true;
  void _onDraftChanged() {
    final empty = _controller.text.isEmpty;
    if (empty != _draftEmpty && mounted) setState(() => _draftEmpty = empty);
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _composerHidden &= !_inputFocus.hasFocus);
  }

  final _composerKey = GlobalKey();

  final _crisisScroll = ScrollController();

  void _showComposer() {
    if (_composerHidden && mounted) setState(() => _composerHidden = false);
  }

  bool _canCollapse(bool cramped) =>
      _touchKeyboard(context) &&
      !cramped &&
      !MediaQuery.accessibleNavigationOf(context);

  void _cancelStick() {
    _stickToEnd = false;
    _stickGen++;
  }

  double _dragRun = 0;
  bool _stickToEnd = false;
  int _stickGen = 0;
  static const _composerToggle = 48.0;

  bool _onUserScroll(ScrollNotification n, bool cramped) {
    if (n.depth != 0 || !_canCollapse(cramped)) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _dragRun = 0;
      _cancelStick();
    } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
      _cancelStick();
      final d = n.scrollDelta ?? 0;
      if (d == 0) return false;
      _dragRun = (d > 0) == (_dragRun > 0) ? _dragRun + d : d;
      if (_dragRun > _composerToggle &&
          n.metrics.extentAfter >= 1 &&
          !_inputFocus.hasFocus &&
          _controller.text.isEmpty) {
        if (!_composerHidden) setState(() => _composerHidden = true);
      } else if (_dragRun < -_composerToggle) {
        _showComposer();
      }
    } else if (n is ScrollEndNotification) {
      _dragRun = 0;
      if (n.metrics.extentAfter < 1 && _composerHidden) {
        _cancelStick();
        setState(() {
          _composerHidden = false;
          _stickToEnd = true;
        });
      }
    }
    return false;
  }

  Future<void> _send() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _sending) return;
    final locale = Localizations.localeOf(context).languageCode;
    setState(() {
      _messages.add(_Message(true, q));
      _sending = true;
      _composerHidden = false;
      _controller.clear();
    });
    _cancelStick();
    _scrollToEnd();
    _Message? crisisTarget;
    WebRestore.begin();
    try {
      final crisisCheckOf = _crisisCheckOf;
      _crisisCheckOf = null;
      final a = await widget.service.ask(
        q,
        locale: locale,
        crisisCheckOf: crisisCheckOf,
        checkedBefore: _messages.any((x) => x.crisisCheck),
      );
      if (mounted) {
        final m = _Message(
          false,
          a.answer,
          sources: a.sources,
          crisis: a.crisis,
          prediction: a.prediction,
          crisisCheck: a.crisisCheck,
          question: q,
          route: a.route,
        );
        final firstLines =
            m.crisisCheck && !_messages.any((x) => x.crisis || x.crisisCheck);
        setState(() => _messages.add(m));
        if (m.crisisCheck) _crisisCheckOf = q;
        if (firstLines) {
          final t = AppLocalizations.of(context)!;
          final dir = Directionality.of(context);
          final view = View.maybeOf(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || view == null) return;
            SemanticsService.sendAnnouncement(view, t.qaCrisisLinesShown, dir);
          });
        }
        if (m.crisis) crisisTarget = m;
      }
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        final msg = switch (e) {
          QaException(error: QaError.rateLimited) => t.qaRateLimited,
          QaException(error: QaError.tooLong) => t.qaTooLong,
          _ => t.qaFailed,
        };
        setState(() => _messages.add(_Message(false, msg)));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _positioning = true;
        _positionTarget = null;
        _positioningDone(after: const Duration(seconds: 3));
        crisisTarget == null
            ? _scrollToEnd(onDone: _positioningDone)
            : _scrollToTop(crisisTarget, onDone: _positioningDone);
      }
      WebRestore.end();
    }
  }

  bool _reporting = false;

  Future<void> _report(_Message m) async {
    if (_reporting) return;
    _reporting = true;
    try {
      await _openReport(m);
    } finally {
      _reporting = false;
    }
  }

  Future<void> _openReport(_Message m) async {
    final t = AppLocalizations.of(context)!;
    final crisisShown = _messages.any((x) => x.crisis || x.crisisCheck);
    final sent = await showReportDialog(
      context,
      service: widget.service,
      question: m.question!,
      answer: m.text,
      route: m.route,
      crisisRow: crisisShown ? _crisisLinesRow(context, t) : null,
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(t.qaReportThanks)));
    }
  }

  String? _crisisCheckOf;

  void _scrollToTop(_Message m, {VoidCallback? onDone}) {
    _cancelStick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _alignTop(m, onDone: onDone);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _alignTop(_Message m, {VoidCallback? onDone}) {
    final ctx = m.key.currentContext;
    if (ctx == null) {
      onDone?.call();
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      alignment: 0,
    ).whenComplete(() => onDone?.call());
  }

  void _scrollToEnd({VoidCallback? onDone}) {
    _cancelStick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_outer.hasClients && _outer.position.hasContentDimensions) {
        _outer.jumpTo(_outer.position.maxScrollExtent);
      }
      if (_scroll.hasClients && _scroll.position.hasContentDimensions) {
        _scroll
            .animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            )
            .whenComplete(() => onDone?.call());
      } else {
        onDone?.call();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;

    final crisisShown = _messages.any((m) => m.crisis || m.crisisCheck);
    final size = MediaQuery.sizeOf(context);
    final rotateNotice =
        kIsWeb &&
        _touchKeyboard(context) &&
        size.width > size.height &&
        !_inputFocus.hasFocus;
    final content = LayoutBuilder(
      builder: (context, c) {
        final tight = c.maxHeight < 480;
        final cramped = c.maxHeight < 320;
        if (cramped && !_wasCramped) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_positioning) {
              _crampedScrollPending = true;
            } else {
              _crampedToBottom();
            }
          });
        }
        if (!cramped) _crampedScrollPending = false;
        _wasCramped = cramped;
        final column = _column(
          context,
          t,
          text,
          crisisShown,
          tight,
          cramped,
          c.maxHeight,
        );
        return cramped
            ? SingleChildScrollView(
                controller: _outer,
                keyboardDismissBehavior: _touchKeyboard(context)
                    ? ScrollViewKeyboardDismissBehavior.onDrag
                    : null,
                child: column,
              )
            : column;
      },
    );
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeFocus(
            excluding: rotateNotice,
            child: ExcludeSemantics(excluding: rotateNotice, child: content),
          ),
        ),
        if (rotateNotice)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.surface,
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(
                                Symbols.screen_rotation_rounded,
                                size: 40,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                t.qaRotatePortrait,
                                style: text.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        if (crisisShown)
                          Semantics(
                            container: true,
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: _crisisLinesRow(context, t),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _crisisLinesRow(BuildContext context, AppLocalizations t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, line) in crisisLines(
        t,
        Localizations.localeOf(context).languageCode,
      ).take(3).indexed) ...[
        if (i > 0) const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: line.color,
            minimumSize: const Size.fromHeight(AppLayout.touchTarget),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => dialLine(context, line),
          child: Text(
            line.short,
            semanticsLabel: line.semantics,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ],
  );

  Widget _column(
    BuildContext context,
    AppLocalizations t,
    TextTheme text,
    bool crisisShown,
    bool tight,
    bool cramped,
    double maxHeight,
  ) {
    if (_composerHidden && !_canCollapse(cramped)) {
      _composerHidden = false;
      _dragRun = 0;
      _cancelStick();
    }
    final collapse = _composerHidden;
    final messages = ListView(
      controller: _scroll,
      keyboardDismissBehavior: _touchKeyboard(context)
          ? ScrollViewKeyboardDismissBehavior.onDrag
          : null,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Material(
          color: AppColors.surfaceContainer,
          child: InkWell(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppLayout.touchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Symbols.cloud_upload_rounded,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tight ? t.qaCloudNoticeShort : t.qaCloudNotice,
                        style: text.bodySmall,
                      ),
                    ),
                    const Icon(
                      Symbols.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        for (final b in [
          _Bubble(message: _Message(false, t.qaWelcome)),
          for (final m in _messages)
            _Bubble(
              key: m.key,
              message: m,
              onReport: widget.service.canReport && m.question != null
                  ? () => _report(m)
                  : null,
            ),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: b,
          ),
        if (_sending)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
            child: Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(t.qaSearching, style: text.bodyMedium)),
                ],
              ),
            ),
          ),
      ],
    );
    final preview = Container(
      width: double.infinity,
      color: AppColors.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Text(
        t.qaPreviewNotice,
        style: text.bodySmall!.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
    final crisis = Semantics(
      container: true,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Scrollbar(
          controller: _crisisScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _crisisScroll,
            child: _crisisLinesRow(context, t),
          ),
        ),
      ),
    );
    final composer = ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: collapse ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        onEnd: () {
          if (!_stickToEnd) return;
          final gen = _stickGen;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || gen != _stickGen || !_stickToEnd) return;
            _stickToEnd = false;
            if (!_composerHidden &&
                !_positioning &&
                _scroll.hasClients &&
                _scroll.position.hasContentDimensions) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          });
          WidgetsBinding.instance.scheduleFrame();
        },
        child: ExcludeSemantics(
          excluding: collapse,
          child: KeyedSubtree(
            key: _composerKey,
            child: _composer(context, t, text, tight),
          ),
        ),
      ),
    );
    if (cramped) {
      return Column(
        children: [
          if (widget.service.isPreview) preview,
          SizedBox(height: 200, child: messages),
          if (crisisShown)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(AppLayout.touchTarget + 8, maxHeight * 0.4),
              ),
              child: crisis,
            ),
          composer,
        ],
      );
    }
    return CustomMultiChildLayout(
      delegate: _QaLayout(),
      children: [
        if (widget.service.isPreview)
          LayoutId(id: _QaSlot.preview, child: preview),
        LayoutId(
          id: _QaSlot.messages,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _onUserScroll(n, cramped),
            child: messages,
          ),
        ),
        if (crisisShown) LayoutId(id: _QaSlot.crisis, child: crisis),
        LayoutId(id: _QaSlot.composer, child: composer),
      ],
    );
  }

  Widget _composer(
    BuildContext context,
    AppLocalizations t,
    TextTheme text,
    bool tight,
  ) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.cardBorder,
            width: AppLayout.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _inputFocus,
              minLines: 1,
              maxLines: tight ? 2 : 4,
              maxLength: CallableQaService.maxLength,
              style: text.bodyMedium,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              onTapUpOutside: _touchKeyboard(context)
                  ? (_) => FocusManager.instance.primaryFocus?.unfocus()
                  : null,
              decoration: InputDecoration(
                hintText: t.qaHint,
                hintMaxLines: 1,
                counterText: _draftEmpty ? '' : null,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppLayout.radius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppLayout.radius),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            height: 56,
            child: IconButton.filled(
              tooltip: t.qaSend,
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(foregroundColor: AppColors.onPrimary),
              icon: const Icon(Symbols.send_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}

bool _touchKeyboard(BuildContext context) =>
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) &&
    (!kIsWeb || MediaQuery.sizeOf(context).shortestSide < 600);

class _Bubble extends StatelessWidget {
  final _Message message;

  final VoidCallback? onReport;
  const _Bubble({super.key, required this.message, this.onReport});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final user = message.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: user ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: user
              ? null
              : Border.all(
                  color: AppColors.cardBorder,
                  width: AppLayout.borderWidth,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.crisis) ...[
              for (final line in crisisLines(
                t,
                Localizations.localeOf(context).languageCode,
              )) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: line.color,
                    minimumSize: const Size.fromHeight(AppLayout.touchTarget),
                  ),
                  onPressed: () => dialLine(context, line),
                  icon: Icon(line.icon),
                  label: Text(
                    line.label,
                    textAlign: TextAlign.center,
                    semanticsLabel: line.semantics,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
            ],
            if (user)
              Text(
                message.text,
                style: text.bodyMedium!.copyWith(color: Colors.white),
              )
            else
              SimpleMarkdown(
                data: message.text,
                style: text.bodyMedium!.copyWith(color: AppColors.onSurface),
              ),
            if (message.prediction) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppLayout.touchTarget),
                ),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const PrepScreen())),
                icon: const Icon(Symbols.backpack_rounded),
                label: Text(t.prepOpenFromQa),
              ),
            ],
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                t.qaSources,
                style: text.labelMedium!.copyWith(color: AppColors.textMuted),
              ),
              for (final (i, s) in message.sources.indexed)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size(0, AppLayout.touchTarget),
                  ),
                  onPressed: () => openExternal(context, s.url),
                  icon: const Icon(Symbols.open_in_new_rounded, size: 18),
                  label: Text(_sourceLabel(message.sources, i)),
                ),
            ],
            if (onReport case final report?) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, AppLayout.touchTarget),
                    foregroundColor: AppColors.onSurfaceVariant,
                  ),
                  onPressed: report,
                  icon: const Icon(Symbols.flag_rounded, size: 18),
                  label: Text(t.qaReport),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _sourceLabel(List<QaSource> sources, int i) {
  final s = sources[i];
  if (s.title.isNotEmpty) return s.label;
  final same = [
    for (final (j, o) in sources.indexed)
      if (o.name == s.name && o.title.isEmpty) j,
  ];
  return same.length < 2 ? s.name : '${s.name} (${same.indexOf(i) + 1})';
}

enum _QaSlot { preview, messages, crisis, composer }


class _QaLayout extends MultiChildLayoutDelegate {
  static const _minMessages = 96.0;

  @override
  void performLayout(Size size) {
    final w = size.width;
    var top = 0.0;
    if (hasChild(_QaSlot.preview)) {
      top = layoutChild(
        _QaSlot.preview,
        BoxConstraints.tightFor(width: w),
      ).height;
      positionChild(_QaSlot.preview, Offset.zero);
    }
    final rest = math.max(0.0, size.height - top);
    final composerH = layoutChild(
      _QaSlot.composer,
      BoxConstraints(minWidth: w, maxWidth: w, maxHeight: rest),
    ).height;
    var crisisH = 0.0;
    if (hasChild(_QaSlot.crisis)) {
      final free = math.max(0.0, rest - composerH);
      final cap = math.min(size.height * 0.4, free - _minMessages);
      final maxH = math.min(free, math.max(cap, AppLayout.touchTarget + 8));
      crisisH = layoutChild(
        _QaSlot.crisis,
        BoxConstraints(minWidth: w, maxWidth: w, maxHeight: maxH),
      ).height;
    }
    final messagesH = math.max(0.0, rest - composerH - crisisH);
    layoutChild(
      _QaSlot.messages,
      BoxConstraints.tightFor(width: w, height: messagesH),
    );
    positionChild(_QaSlot.messages, Offset(0, top));
    if (hasChild(_QaSlot.crisis)) {
      positionChild(_QaSlot.crisis, Offset(0, top + messagesH));
    }
    positionChild(_QaSlot.composer, Offset(0, top + messagesH + crisisH));
  }

  @override
  bool shouldRelayout(_QaLayout oldDelegate) => false;
}
