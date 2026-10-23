import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../utils/design_constants.dart';
import 'depot_model.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Palette de la cour. Le dépôt existe en plein jour et sous éclairage
/// sodium : ce sont les mêmes volumes, pas les mêmes teintes.
/// ─────────────────────────────────────────────────────────────────────────
class YardPalette {
  final Color sky, tarmac, tarmacAlt, tarmacEdge, line;
  final Color bldTop, bldRight, bldLeft;
  final Color chassis, glass, shadow, ghost, pinStroke, mutedPin;

  const YardPalette({
    required this.sky,
    required this.tarmac,
    required this.tarmacAlt,
    required this.tarmacEdge,
    required this.line,
    required this.bldTop,
    required this.bldRight,
    required this.bldLeft,
    required this.chassis,
    required this.glass,
    required this.shadow,
    required this.ghost,
    required this.pinStroke,
    required this.mutedPin,
  });

  static const _light = YardPalette(
    sky:        Color(0xFFD8D3C9),
    tarmac:     Color(0xFFB7B2A8),
    tarmacAlt:  Color(0xFFABA69C),
    tarmacEdge: Color(0xFF9C978C),
    line:       Color(0xFFF2E9C8),
    bldTop:     Color(0xFFEDE8DF),
    bldRight:   Color(0xFFCFC8BC),
    bldLeft:    Color(0xFFAEA69A),
    chassis:    Color(0xFF32373D),
    glass:      Color(0xFF1D2227),
    shadow:     Color(0x2B1B1E22),
    ghost:      Color(0xFF4A7FA5),
    pinStroke:  Color(0xFFD8D3C9),
    mutedPin:   Color(0xFF5D6671),
  );

  static const _dark = YardPalette(
    sky:        Color(0xFF0E1113),
    tarmac:     Color(0xFF2B3034),
    tarmacAlt:  Color(0xFF24292D),
    tarmacEdge: Color(0xFF1C2024),
    line:       Color(0xFF6B5C2A),
    bldTop:     Color(0xFF363C42),
    bldRight:   Color(0xFF262B30),
    bldLeft:    Color(0xFF1B1F23),
    chassis:    Color(0xFF32373D),
    glass:      Color(0xFF14181C),
    shadow:     Color(0x73000000),
    ghost:      Color(0xFF7FAFD3),
    pinStroke:  Color(0xFF0E1113),
    mutedPin:   Color(0xFF9AA2AB),
  );

  factory YardPalette.of(bool dark) => dark ? _dark : _light;
}

/// Teinte d'un camion : face haute, face droite, face gauche.
class _Livery {
  final Color top, right, left;
  const _Livery(this.top, this.right, this.left);
}

const _liveries = <YardState, _Livery>{
  YardState.dispo: _Livery(Color(0xFF44997F), Color(0xFF2F6E5B), Color(0xFF215040)),
  YardState.ct:    _Livery(Color(0xFFEDC751), Color(0xFFCBA11C), Color(0xFF9A7A0F)),
  YardState.panne: _Livery(Color(0xFFE26A3C), Color(0xFFBF4612), Color(0xFF8F2F0A)),
  YardState.tournee: _Livery(Color(0xFFBCC1C7), Color(0xFF8E959C), Color(0xFF6B7278)),
};

Color yardStateColor(YardState s, YardPalette pal) =>
    s == YardState.tournee ? pal.ghost : _liveries[s]!.right;

/// Glyphes restreints aux caractères réellement présents dans IBM Plex Mono.
/// L'état normal n'en porte pas : seules les exceptions se signalent.
const _glyphs = <YardState, String>{
  YardState.dispo: '',
  YardState.ct: '!',
  YardState.panne: '×',
  YardState.tournee: '→',
};

/// ─────────────────────────────────────────────────────────────────────────
/// Plan de la cour, en unités « tuile ». Indépendant du rendu : c'est lui
/// qui décide où tombe chaque emplacement selon la taille de la flotte.
/// ─────────────────────────────────────────────────────────────────────────
class YardBuilding {
  final String id, label;
  final double x, y, w, d, h;
  final Color roof;
  final int windows;
  final bool wideDoor, canopy;
  const YardBuilding(this.id, this.label, this.x, this.y, this.w, this.d, this.h,
      this.roof, {this.windows = 0, this.wideDoor = false, this.canopy = false});
}

class DepotLayout {
  static const double bayW = 2.0, bayD = 1.1;
  static const double pitchX = 2.6, pitchY = 1.8;
  static const double originX = 2.9, originY = 0.5;

  final int cols, rows;
  final double gridW, gridD;
  final List<Offset> bays;
  final List<YardBuilding> buildings;
  final List<Offset> peopleSpots;
  final List<Offset> apronSpots;

  DepotLayout._(this.cols, this.rows, this.gridW, this.gridD, this.bays,
      this.buildings, this.peopleSpots, this.apronSpots);

  factory DepotLayout.forBays(int bayCount) {
    final cols = bayCount <= 8 ? 2 : 3;
    final rows = (bayCount / cols).ceil();

    final gridW = (originX + cols * pitchX - (pitchX - bayW) + 1.5).ceilToDouble();
    final gridD =
        math.max(8.0, originY + rows * pitchY - (pitchY - bayD) + 3.0).ceilToDouble();

    final bays = <Offset>[];
    for (var i = 0; i < bayCount; i++) {
      bays.add(Offset(
        originX + (i % cols) * pitchX,
        originY + (i ~/ cols) * pitchY,
      ));
    }

    final buildings = <YardBuilding>[
      YardBuilding('bureau', 'Bureau', 0.1, 0.1, 2.2, 2.2, 38,
          const Color(0xFF3C6D90), windows: 3),
      YardBuilding('atelier', 'Atelier', 0.2, gridD - 2.5, 2.3, 2.3, 30,
          const Color(0xFFC2481A), windows: 2, wideDoor: true),
      YardBuilding('pompe', 'Pompe', gridW - 1.05, 0.3, 0.85, 1.0, 18,
          const Color(0xFFD9A50F), canopy: true),
    ];

    // Tablier devant l'atelier : les immobilisés y sont garés, hors emplacement.
    final apronCount = math.max(1, ((gridW - 3.4) / 2.2).floor());
    final apronSpots = <Offset>[
      for (var i = 0; i < apronCount; i++) Offset(3.0 + i * 2.2, gridD - 1.75),
    ];

    final peopleSpots = <Offset>[
      Offset(gridW - 2.9, gridD - 1.4),
      Offset(gridW - 1.5, gridD - 1.4),
      Offset(gridW - 0.1, gridD - 1.4),
    ];

    return DepotLayout._(
        cols, rows, gridW, gridD, bays, buildings, peopleSpots, apronSpots);
  }
}

/// Zone cliquable, en coordonnées écran, remplie pendant le rendu.
class DepotHit {
  final String id;
  final Path path;
  final double depth;
  const DepotHit(this.id, this.path, this.depth);
}

/// ─────────────────────────────────────────────────────────────────────────
/// Le peintre.
/// ─────────────────────────────────────────────────────────────────────────
class DepotPainter extends CustomPainter {
  final YardData data;
  final DepotLayout layout;
  final YardPalette pal;
  final String? selectedId;
  final YardState? highlight;

  /// Rempli à chaque rendu, consommé par le détecteur de gestes.
  final List<DepotHit> hits;

  DepotPainter({
    required this.data,
    required this.layout,
    required this.pal,
    required this.hits,
    this.selectedId,
    this.highlight,
  });

  static const double tw = 38, th = 24;

  double _s = 1;
  Offset _o = Offset.zero;

  Offset _p(double x, double y, [double h = 0]) => Offset(
        _o.dx + (x - y) * tw / 2 * _s,
        _o.dy + ((x + y) * th / 2 - h) * _s,
      );

  @override
  void paint(Canvas canvas, Size size) {
    hits.clear();

    // ── Cadrage : la scène entière tient dans la surface disponible ──
    const double maxLift = 46; // bâtiment le plus haut + auvent
    final left = -layout.gridD * tw / 2 - 4;
    final right = layout.gridW * tw / 2 + 4;
    final top = -maxLift - 16;
    final bottom = (layout.gridW + layout.gridD) * th / 2 + 12;
    final bw = right - left, bh = bottom - top;

    _s = math.min(size.width / bw, size.height / bh);
    _o = Offset(
      -left * _s + (size.width - bw * _s) / 2,
      -top * _s + (size.height - bh * _s) / 2,
    );

    _paintFloor(canvas);

    // ── Volumes, triés par profondeur (centre de gravité) ──
    final drawables = <_Drawable>[];

    for (final b in layout.buildings) {
      drawables.add(_Drawable(
        depth: (b.x + b.w / 2) + (b.y + b.d / 2),
        paint: (c) => _paintBuilding(c, b),
      ));
    }

    var apron = 0;
    final placed = <YardTruck, Offset>{};
    for (final t in data.trucks) {
      Offset spot;
      if (t.atWorkshop && apron < layout.apronSpots.length) {
        spot = layout.apronSpots[apron++];
      } else {
        spot = layout.bays[t.bay % layout.bays.length];
      }
      placed[t] = spot;
      drawables.add(_Drawable(
        depth: (spot.dx + DepotLayout.bayW / 2) + (spot.dy + DepotLayout.bayD / 2),
        paint: (c) => _paintTruck(c, t, spot),
      ));
    }

    for (var i = 0; i < data.people.length && i < layout.peopleSpots.length; i++) {
      final spot = layout.peopleSpots[i];
      final person = data.people[i];
      drawables.add(_Drawable(
        depth: spot.dx + spot.dy,
        paint: (c) => _paintPerson(c, person, spot),
      ));
    }

    drawables.sort((a, b) => a.depth.compareTo(b.depth));
    for (final d in drawables) {
      d.paint(canvas);
    }

    // ── Épingles : la seule couche qu'aucun volume ne peut recouvrir ──
    _paintPins(canvas, placed);
  }

  // ── Sol ────────────────────────────────────────────────────────────────
  void _paintFloor(Canvas canvas) {
    final w = layout.gridW.ceil(), d = layout.gridD.ceil();
    final tile = Paint()..color = pal.tarmac;
    final alt = Paint()..color = pal.tarmacAlt;

    for (var i = 0; i < w; i++) {
      for (var j = 0; j < d; j++) {
        canvas.drawPath(
          Path()..addPolygon([
            _p(i.toDouble(), j.toDouble()),
            _p(i + 1.0, j.toDouble()),
            _p(i + 1.0, j + 1.0),
            _p(i.toDouble(), j + 1.0),
          ], true),
          (i + j).isEven ? tile : alt,
        );
      }
    }

    canvas.drawPath(
      Path()..addPolygon([
        _p(0, 0),
        _p(layout.gridW, 0),
        _p(layout.gridW, layout.gridD),
        _p(0, layout.gridD),
      ], true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = pal.tarmacEdge,
    );

    // Marquage des emplacements
    final occupied = <int, YardTruck>{
      for (final t in data.trucks) t.bay % layout.bays.length: t,
    };

    for (var i = 0; i < layout.bays.length; i++) {
      final b = layout.bays[i];
      final t = occupied[i];
      final away = t != null && t.atWorkshop;
      final vacant = t == null || away;

      final path = Path()..addPolygon([
        _p(b.dx, b.dy),
        _p(b.dx + DepotLayout.bayW, b.dy),
        _p(b.dx + DepotLayout.bayW, b.dy + DepotLayout.bayD),
        _p(b.dx, b.dy + DepotLayout.bayD),
      ], true);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeJoin = StrokeJoin.round
        ..color = away
            ? _liveries[YardState.panne]!.right.withValues(alpha: 0.8)
            : pal.line.withValues(alpha: vacant ? 0.5 : 0.72);

      canvas.drawPath(vacant ? _dashed(path, 5, 4) : path, paint);

      if (t == null) {
        // Un emplacement libre se touche aussi : c'est là qu'on ajoute un camion.
        hits.add(DepotHit('bay:$i', path,
            (b.dx + DepotLayout.bayW / 2) + (b.dy + DepotLayout.bayD / 2)));
      }
    }
  }

  // ── Bâtiments ──────────────────────────────────────────────────────────
  void _paintBuilding(Canvas canvas, YardBuilding b) {
    _shadow(canvas, b.x + b.w / 2, b.y + b.d / 2, b.w * 0.8, b.d * 0.8);
    _box(canvas, b.x, b.y, b.w, b.d, b.h, 0, pal.bldTop, pal.bldRight, pal.bldLeft);

    // Acrotère coloré, puis nappe de toit neutre : la couleur reste un liseré.
    _box(canvas, b.x + .06, b.y + .06, b.w - .12, b.d - .12, 3.5, b.h,
        b.roof, b.roof, b.roof);
    _box(canvas, b.x + .26, b.y + .26, b.w - .52, b.d - .52, 1.4, b.h + 3.4,
        pal.bldRight, pal.bldRight, pal.bldRight);

    final xF = b.x + b.w, yF = b.y + b.d;

    if (b.wideDoor) {
      _panelY(canvas, yF, b.x + .45, xF - .45, 0, b.h * .62, pal.glass, .85);
      _panelY(canvas, yF, b.x + .45, xF - .45, b.h * .60, b.h * .64, b.roof, .9);
    } else if (b.windows > 0) {
      _panelY(canvas, yF, b.x + .85, b.x + 1.35, 0, 14, pal.glass, .8);
    }

    for (var k = 0; k < b.windows; k++) {
      final w0 = b.y + .35 + k * ((b.d - .7) / b.windows);
      _panelX(canvas, xF, w0, w0 + .42, b.h * .45, b.h * .74, pal.glass, .55);
    }

    if (b.canopy) {
      _box(canvas, b.x - .32, b.y - .28, b.w + .64, b.d + .56, 2.5, b.h + 9,
          b.roof, b.roof, b.roof);
      _box(canvas, b.x + .36, b.y + .42, .14, .16, 9, b.h,
          pal.chassis, pal.chassis, pal.chassis);
    }

    final footprint = _silhouette(b.x, b.y, b.w, b.d, b.h);

    if (selectedId == 'bld:${b.id}') {
      _halo(canvas, b.x, b.y, b.w, b.d, b.h);
    }
    hits.add(DepotHit('bld:${b.id}', footprint,
        (b.x + b.w / 2) + (b.y + b.d / 2)));

    _label(canvas, _p(b.x + b.w / 2, b.y + b.d / 2, b.h + (b.canopy ? 20 : 11)),
        b.label.toUpperCase(), 8.0, pal.bldTop, bold: true);
  }

  // ── Camions ────────────────────────────────────────────────────────────
  void _paintTruck(Canvas canvas, YardTruck t, Offset p) {
    final x = p.dx, y = p.dy;
    final id = 'truck:${t.truck.plate}';

    // Pendant un filtre de légende, ce qui ne correspond pas s'estompe au lieu
    // de disparaître : la cour garde sa forme, seul le sujet ressort.
    final dimmed = highlight != null && highlight != t.state;
    if (dimmed) canvas.saveLayer(null, Paint()..color = const Color(0x40000000));

    if (t.isGhost) {
      _shadow(canvas, x + 1.0, y + .55, 1.5, .9, alpha: .22);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = pal.ghost;

      final base = Path()..addPolygon([
        _p(x + .1, y + .12), _p(x + 1.9, y + .12),
        _p(x + 1.9, y + .98), _p(x + .1, y + .98),
      ], true);
      final roof = Path()..addPolygon([
        _p(x + .1, y + .12, 17), _p(x + 1.9, y + .12, 17),
        _p(x + 1.9, y + .98, 17), _p(x + .1, y + .98, 17),
      ], true);
      canvas.drawPath(_dashed(base, 4, 3), stroke);
      canvas.drawPath(_dashed(roof, 4, 3), stroke);
      for (final cx in [x + .1, x + 1.9]) {
        canvas.drawLine(_p(cx, y + .98), _p(cx, y + .98, 17), stroke);
      }
    } else {
      final lv = _liveries[t.state]!;
      _shadow(canvas, x + 1.0, y + .6, 1.5, .78);
      _box(canvas, x + .28, y + .92, .34, .14, 3.2, 0,
          pal.chassis, pal.chassis, pal.chassis);
      _box(canvas, x + 1.42, y + .92, .34, .14, 3.2, 0,
          pal.chassis, pal.chassis, pal.chassis);
      _box(canvas, x + .05, y + .12, 1.90, .86, 3.5, 0,
          pal.chassis, pal.chassis, pal.chassis);
      _box(canvas, x + .08, y + .08, 1.24, .94, 17, 3.5, lv.top, lv.right, lv.left);
      _box(canvas, x + 1.42, y + .13, .48, .84, 10, 3.5, lv.top, lv.right, lv.left);
      _panelX(canvas, x + 1.90, y + .22, y + .88, 9, 13, pal.glass, .9);
      _panelY(canvas, y + .97, x + 1.46, x + 1.86, 9, 13, pal.glass, .55);
    }

    if (dimmed) canvas.restore();

    final footprint = _silhouette(
        x, y, DepotLayout.bayW, DepotLayout.bayD, t.isGhost ? 17 : 21);

    if (selectedId == id || (highlight != null && !dimmed)) {
      _halo(canvas, x, y, DepotLayout.bayW, DepotLayout.bayD,
          t.isGhost ? 17 : 21);
    }

    hits.add(DepotHit(id, footprint,
        (x + DepotLayout.bayW / 2) + (y + DepotLayout.bayD / 2)));
  }

  // ── Chauffeurs ─────────────────────────────────────────────────────────
  void _paintPerson(Canvas canvas, YardPerson person, Offset spot) {
    final c = _p(spot.dx, spot.dy);
    final k = _s;
    final body = person.alert
        ? _liveries[YardState.panne]!.right
        : _liveries[YardState.ct]!.right;
    final trim = person.alert
        ? _liveries[YardState.panne]!.top
        : _liveries[YardState.ct]!.top;

    _shadow(canvas, spot.dx, spot.dy, .4, .3);

    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 3.4 * k, c.dy - 1 * k)
        ..lineTo(c.dx - 2.6 * k, c.dy - 11 * k)
        ..lineTo(c.dx + 2.6 * k, c.dy - 11 * k)
        ..lineTo(c.dx + 3.4 * k, c.dy - 1 * k)
        ..close(),
      Paint()..color = pal.chassis,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - 3.9 * k, c.dy - 19 * k, 7.8 * k, 9 * k),
        Radius.circular(2.6 * k),
      ),
      Paint()..color = body,
    );
    canvas.drawRect(
      Rect.fromLTWH(c.dx - 3.9 * k, c.dy - 13.4 * k, 7.8 * k, 1.9 * k),
      Paint()..color = trim,
    );
    canvas.drawCircle(
        Offset(c.dx, c.dy - 21.6 * k), 3.3 * k, Paint()..color = const Color(0xFF8A929B));

    hits.add(DepotHit(
      'driver:${person.driver.name}',
      Path()..addRect(Rect.fromLTWH(c.dx - 11 * k, c.dy - 28 * k, 22 * k, 32 * k)),
      spot.dx + spot.dy,
    ));
  }

  // ── Épingles ───────────────────────────────────────────────────────────
  void _paintPins(Canvas canvas, Map<YardTruck, Offset> placed) {
    // En dessous d'une certaine échelle les épingles se chevauchent : on ne
    // garde alors que celles qui portent une information d'alerte.
    final dense = _s < 0.72;

    placed.forEach((t, spot) {
      final selected = selectedId == 'truck:${t.truck.plate}';
      if (dense && t.state == YardState.dispo && !selected) return;
      if (highlight != null && highlight != t.state && !selected) return;

      final at = _p(spot.dx + 1.0, spot.dy + .55, t.isGhost ? 26 : 32);
      final g = _glyphs[t.state]!;
      _pin(canvas, at, g.isEmpty ? t.truck.plate : '$g ${t.truck.plate}',
          yardStateColor(t.state, pal), t.state == YardState.ct);
    });

    if (highlight == null) {
      final occupied = {for (final t in data.trucks) t.bay % layout.bays.length};
      for (var i = 0; i < layout.bays.length; i++) {
        if (occupied.contains(i)) continue;
        final b = layout.bays[i];
        _pin(canvas, _p(b.dx + 1.0, b.dy + .55, 15), 'LIBRE', pal.mutedPin, false,
            dashed: true);
      }

      for (var i = 0; i < data.people.length && i < layout.peopleSpots.length; i++) {
        final spot = layout.peopleSpots[i];
        final person = data.people[i];
        final color = person.alert
            ? _liveries[YardState.panne]!.right
            : _liveries[YardState.ct]!.right;
        _pin(canvas, _p(spot.dx, spot.dy, 40), _shortName(person.driver.name),
            color, !person.alert);
      }
    }
  }

  static String _shortName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return full;
    return '${parts.first} ${parts[1][0].toUpperCase()}.';
  }

  void _pin(Canvas canvas, Offset at, String text, Color fill, bool darkInk,
      {bool dashed = false}) {
    final fs = (8.0 * _s).clamp(6.5, 9.5).toDouble();
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: DC.mono(fs,
            weight: FontWeight.w600,
            color: dashed ? fill : (darkInk ? const Color(0xFF17191C) : Colors.white)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final w = tp.width + 11, h = tp.height + 4;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(at.dx - w / 2, at.dy - h, w, h),
      const Radius.circular(4),
    );

    final body = Paint()..color = dashed ? fill.withValues(alpha: 0.22) : fill;
    canvas.drawRRect(rect, body);
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = dashed ? fill.withValues(alpha: .75) : pal.pinStroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - 3.2, at.dy - 0.4)
        ..lineTo(at.dx + 3.2, at.dy - 0.4)
        ..lineTo(at.dx, at.dy + 4)
        ..close(),
      Paint()..color = dashed ? fill.withValues(alpha: .5) : fill,
    );
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - h + 2));
  }

  void _label(Canvas canvas, Offset at, String text, double size, Color halo,
      {bool bold = false}) {
    final style = DC.mono((size * _s).clamp(7.0, 10.0).toDouble(),
        weight: bold ? FontWeight.w600 : FontWeight.w500,
        color: pal.bldTop == const Color(0xFFEDE8DF)
            ? const Color(0xFF1B1E22)
            : const Color(0xFFECE8E1));

    final stroke = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeJoin = StrokeJoin.round
            ..color = pal.sky,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    stroke.paint(canvas, Offset(at.dx - stroke.width / 2, at.dy - stroke.height / 2));

    final fill = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    fill.paint(canvas, Offset(at.dx - fill.width / 2, at.dy - fill.height / 2));
  }

  // ── Primitives ─────────────────────────────────────────────────────────
  void _box(Canvas canvas, double x, double y, double w, double d, double h,
      double base, Color top, Color right, Color left) {
    final aT = _p(x, y, base + h),
        bT = _p(x + w, y, base + h),
        cT = _p(x + w, y + d, base + h),
        dT = _p(x, y + d, base + h);
    final bB = _p(x + w, y, base),
        cB = _p(x + w, y + d, base),
        dB = _p(x, y + d, base);

    canvas.drawPath(Path()..addPolygon([dT, cT, cB, dB], true), Paint()..color = left);
    canvas.drawPath(Path()..addPolygon([bT, cT, cB, bB], true), Paint()..color = right);
    canvas.drawPath(Path()..addPolygon([aT, bT, cT, dT], true), Paint()..color = top);
  }

  /// Panneau plaqué sur la face gauche (+y) : porte, vitre latérale.
  void _panelY(Canvas canvas, double y, double x0, double x1, double h0,
      double h1, Color color, double alpha) {
    canvas.drawPath(
      Path()..addPolygon([_p(x0, y, h1), _p(x1, y, h1), _p(x1, y, h0), _p(x0, y, h0)], true),
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  /// Panneau plaqué sur la face droite (+x) : fenêtres, pare-brise.
  void _panelX(Canvas canvas, double x, double y0, double y1, double h0,
      double h1, Color color, double alpha) {
    canvas.drawPath(
      Path()..addPolygon([_p(x, y0, h1), _p(x, y1, h1), _p(x, y1, h0), _p(x, y0, h0)], true),
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  void _shadow(Canvas canvas, double cx, double cy, double rx, double ry,
      {double alpha = 1}) {
    final c = _p(cx, cy);
    canvas.drawOval(
      Rect.fromCenter(
        center: c,
        width: rx * tw * _s,
        height: ry * th * _s,
      ),
      Paint()
        ..color = pal.shadow.withValues(alpha: pal.shadow.a * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * _s),
    );
  }

  /// Contour du volume tel qu'il apparaît à l'écran : c'est lui qui sert de
  /// zone sensible, pour qu'on touche le camion et non la dalle sous lui.
  Path _silhouette(double x, double y, double w, double d, double h) =>
      Path()..addPolygon([
        _p(x, y, h),
        _p(x + w, y, h),
        _p(x + w, y, 0),
        _p(x + w, y + d, 0),
        _p(x, y + d, 0),
        _p(x, y + d, h),
      ], true);

  void _halo(Canvas canvas, double x, double y, double w, double d, double h) {
    canvas.drawPath(
      Path()..addPolygon([
        _p(x, y, h), _p(x + w, y, h), _p(x + w, y + d, h), _p(x, y + d, h),
      ], true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFF0BF26),
    );
  }

  static Path _dashed(Path source, double on, double off) {
    final out = Path();
    for (final PathMetric m in source.computeMetrics()) {
      var dist = 0.0;
      while (dist < m.length) {
        out.addPath(m.extractPath(dist, math.min(dist + on, m.length)), Offset.zero);
        dist += on + off;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant DepotPainter old) =>
      old.data != data ||
      old.selectedId != selectedId ||
      old.highlight != highlight ||
      old.pal != pal;
}

class _Drawable {
  final double depth;
  final void Function(Canvas) paint;
  const _Drawable({required this.depth, required this.paint});
}
