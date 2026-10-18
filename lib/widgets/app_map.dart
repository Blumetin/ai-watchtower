import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPoint {
  final double lat;
  final double lon;
  const MapPoint(this.lat, this.lon);
}

class MapCircle {
  final MapPoint center;
  final double radius;
  final Color fill;
  final Color border;
  const MapCircle(this.center, this.radius, this.fill, this.border);
}

class AppMap extends StatefulWidget {
  final MapPoint center;
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final List<MapCircle> circles;

  final List<MapPoint> crosses;
  final Color crossColor;

  final bool simpleGestures;

  final List<MapPoint>? fit;

  final EdgeInsets fitPadding;

  final double? fitMaxZoom;

  final void Function(MapPoint center, double zoom)? onCameraMove;

  const AppMap({
    super.key,
    required this.center,
    required this.zoom,
    this.minZoom = 3,
    this.maxZoom = 16,
    this.circles = const [],
    this.crosses = const [],
    this.crossColor = Colors.red,
    this.simpleGestures = false,
    this.fit,
    this.fitPadding = const EdgeInsets.all(24),
    this.fitMaxZoom,
    this.onCameraMove,
  });

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  GoogleMapController? _controller;
  bool _needsRefit = false;
  bool _scheduled = false;
  Size? _size;

  final Map<String, BitmapDescriptor> _icons = {};
  final Set<String> _pending = {};
  double? _dpr;

  int _iconsVersion = 0;
  bool _iconRebuildScheduled = false;

  Set<Marker>? _markerCache;
  Object? _markerCacheKey;

  static LatLng _ll(MapPoint p) => LatLng(p.lat, p.lon);

  static bool _sameFit(List<MapPoint>? a, List<MapPoint>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].lat != b[i].lat || a[i].lon != b[i].lon) return false;
    }
    return true;
  }


  CameraPosition? _fitCamera() {
    final points = widget.fit;
    final size = _size;
    if (points == null || points.isEmpty || size == null) return null;
    final pad = widget.fitPadding;
    final w = size.width - pad.horizontal, h = size.height - pad.vertical;
    if (w <= 0 || h <= 0) return null;
    double x(double lon) => (lon + 180) / 360;
    double y(double lat) {
      final s = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
      return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
    }

    var minX = x(points.first.lon), maxX = minX;
    var minY = y(points.first.lat), maxY = minY;
    for (final p in points) {
      minX = math.min(minX, x(p.lon));
      maxX = math.max(maxX, x(p.lon));
      minY = math.min(minY, y(p.lat));
      maxY = math.max(maxY, y(p.lat));
    }
    final limit = widget.fitMaxZoom ?? widget.maxZoom;
    var zoom = limit;
    double log2(double v) => math.log(v) / math.ln2;
    if (maxX > minX) zoom = math.min(zoom, log2(w / (256 * (maxX - minX))));
    if (maxY > minY) zoom = math.min(zoom, log2(h / (256 * (maxY - minY))));
    zoom = zoom.clamp(widget.minZoom, limit);
    final world = 256 * math.pow(2, zoom).toDouble();
    final mx = (minX + maxX) / 2 * world + (pad.right - pad.left) / 2;
    final my = (minY + maxY) / 2 * world + (pad.bottom - pad.top) / 2;
    final lon = (mx / world * 360 - 180).clamp(-180.0, 180.0);
    final n = math.pi * (1 - 2 * my / world);
    final lat = math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
    return CameraPosition(target: LatLng(lat, lon), zoom: zoom);
  }

  void _refitLater() {
    _needsRefit = true;
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _refitNow();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  Future<void> _refitNow() async {
    final controller = _controller;
    if (controller == null || !_needsRefit) return;
    final camera = _fitCamera();
    if (camera == null) return;
    _needsRefit = false;
    try {
      await controller.moveCamera(CameraUpdate.newCameraPosition(camera));
    } catch (e) {
      debugPrint('AppMap: fit failed: $e');
    }
  }

  void _onCreated(GoogleMapController c) {
    if (!mounted) return;
    _controller = c;
    _refitLater();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (dpr != _dpr) {
      _dpr = dpr;
      _icons.clear();
      _pending.clear();
      _iconsVersion++;
    }
    _ensureIcons();
  }

  @override
  void didUpdateWidget(AppMap old) {
    super.didUpdateWidget(old);
    if (!_sameFit(old.fit, widget.fit) ||
        old.fitPadding != widget.fitPadding ||
        old.fitMaxZoom != widget.fitMaxZoom ||
        old.minZoom != widget.minZoom ||
        old.maxZoom != widget.maxZoom) {
      _refitLater();
    }
    _ensureIcons();
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }


  static String _circleKey(MapCircle c) =>
      'c:${(c.radius * 2).round()}:${c.fill.toARGB32()}:${c.border.toARGB32()}';

  String get _crossKey => 'x:${widget.crossColor.toARGB32()}';

  static const _crossSize = 40.0;

  void _ensureIcons() {
    final dpr = _dpr;
    if (dpr == null) return;
    for (final c in widget.circles) {
      final key = _circleKey(c);
      if (_icons.containsKey(key) || !_pending.add(key)) continue;
      final r = (c.radius * 2).round() / 2;
      final fill = c.fill, border = c.border;
      _paint(key, dpr, Size.square(r * 2 + 2), (canvas, size) {
        final center = size.center(Offset.zero);
        canvas.drawCircle(center, r, Paint()..color = fill);
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = border
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      });
    }
    if (widget.crosses.isNotEmpty) {
      final key = _crossKey;
      if (!_icons.containsKey(key) && _pending.add(key)) {
        final color = widget.crossColor;
        _paint(key, dpr, const Size.square(_crossSize), (canvas, size) {
          final paint = Paint()
            ..color = color
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round;
          const m = 10.0;
          canvas.drawLine(
            const Offset(m, m),
            Offset(size.width - m, size.height - m),
            paint,
          );
          canvas.drawLine(
            Offset(size.width - m, m),
            Offset(m, size.height - m),
            paint,
          );
        });
      }
    }
  }

  Future<void> _paint(
    String key,
    double dpr,
    Size size,
    void Function(Canvas canvas, Size size) draw,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    draw(canvas, size);
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(
        (size.width * dpr).ceil(),
        (size.height * dpr).ceil(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || !mounted || _dpr != dpr) return;
      _icons[key] = BitmapDescriptor.bytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width: size.width,
        height: size.height,
      );
      _iconsVersion++;
      _scheduleIconRebuild();
    } catch (e) {
      debugPrint('AppMap: marker icon failed: $e');
    } finally {
      image?.dispose();
      picture.dispose();
      if (_dpr == dpr) _pending.remove(key);
    }
  }

  void _scheduleIconRebuild() {
    if (_iconRebuildScheduled) return;
    _iconRebuildScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _iconRebuildScheduled = false;
      if (mounted) setState(() {});
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  Set<Marker> _markers() {
    final cacheKey = (
      widget.circles,
      widget.circles.length,
      widget.crosses,
      widget.crosses.length,
      widget.crossColor,
      _iconsVersion,
    );
    final cached = _markerCache;
    if (cached != null && _markerCacheKey == cacheKey) return cached;
    final markers = <Marker>{};
    for (final (i, c) in widget.circles.indexed) {
      final icon = _icons[_circleKey(c)];
      if (icon == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId('c$i'),
          position: _ll(c.center),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: true,
          zIndexInt: 10000 - (c.radius * 10).round(),
        ),
      );
    }
    final cross = _icons[_crossKey];
    if (cross != null) {
      for (final (j, p) in widget.crosses.indexed) {
        markers.add(
          Marker(
            markerId: MarkerId('x$j'),
            position: _ll(p),
            icon: cross,
            anchor: const Offset(0.5, 0.5),
            consumeTapEvents: true,
            zIndexInt: 100000,
          ),
        );
      }
    }
    _markerCache = markers;
    _markerCacheKey = cacheKey;
    return markers;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final points = widget.fit;
      if (points != null &&
          points.isNotEmpty &&
          c.hasBoundedWidth &&
          c.hasBoundedHeight) {
        final size = c.biggest;
        if (_size != null && _size != size) _refitLater();
        _size = size;
      }
      return GoogleMap(
        initialCameraPosition:
            _fitCamera() ??
            CameraPosition(target: _ll(widget.center), zoom: widget.zoom),
        onMapCreated: _onCreated,
        minMaxZoomPreference: MinMaxZoomPreference(
          widget.minZoom,
          widget.maxZoom,
        ),
        markers: _markers(),
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        compassEnabled: false,
        mapToolbarEnabled: false,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        indoorViewEnabled: false,
        trafficEnabled: false,
        buildingsEnabled: false,
        mapTypeControlEnabled: false,
        streetViewControlEnabled: false,
        fullscreenControlEnabled: false,
        gestureRecognizers: widget.simpleGestures && !kIsWeb
            ? {
                Factory<OneSequenceGestureRecognizer>(
                  EagerGestureRecognizer.new,
                ),
              }
            : const {},
        webGestureHandling: WebGestureHandling.greedy,
        onCameraMove: widget.onCameraMove == null
            ? null
            : (p) => widget.onCameraMove!(
                MapPoint(p.target.latitude, p.target.longitude),
                p.zoom,
              ),
      );
    },
  );
}
