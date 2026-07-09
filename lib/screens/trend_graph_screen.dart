import 'package:flutter/material.dart';
import 'dart:math';
import '../database_helper.dart';

class TrendGraphScreen extends StatefulWidget {
  final int userId;
  final String patientName;
  final String language;

  const TrendGraphScreen({
    super.key,
    required this.userId,
    required this.patientName,
    required this.language,
  });

  @override
  State<TrendGraphScreen> createState() => _TrendGraphScreenState();
}

class _TrendGraphScreenState extends State<TrendGraphScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _screenings = [];
  bool _isLoading = true;
  late AnimationController _animController;
  late Animation<double> _drawAnim;

  bool get isHindi => widget.language == 'Hindi';
  String t(String en, String hi) => isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _drawAnim = CurvedAnimation(
        parent: _animController, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getScreeningsByPatientName(
      userId: widget.userId,
      patientName: widget.patientName,
    );
    setState(() {
      _screenings = data;
      _isLoading = false;
    });
    _animController.forward();
  }

  double _saheliScore(Map<String, dynamic> s) {
    final symptomCount = [
      s['fatigue'] == 1, s['dizziness'] == 1, s['paleSkin'] == 1,
      s['shortnessOfBreath'] == 1, s['heavyPeriods'] == 1, s['headache'] == 1,
    ].where((v) => v).length;
    final pallor = (s['mlScore'] as num).toDouble() * 6.0;
    final symptom = (symptomCount / 6.0) * 2.5;
    double rf = 0.0;
    if (s['reason'] == 'Pregnancy') rf += 0.9;
    final age = s['age'] as int;
    if (age < 18 || age > 45) rf += 0.6;
    return (pallor + symptom + rf).clamp(0.0, 10.0);
  }

  Color _scoreColor(double score) {
    if (score >= 7.5) return Colors.red.shade600;
    if (score >= 5.5) return Colors.orange;
    if (score >= 3.5) return Colors.amber.shade700;
    return Colors.green.shade600;
  }

  String _scoreLabel(double score) {
    if (score >= 7.5) return t('Severe', 'गंभीर');
    if (score >= 5.5) return t('Moderate', 'मध्यम');
    if (score >= 3.5) return t('Mild', 'हल्का');
    return t('Normal', 'सामान्य');
  }

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso);
    return '${dt.day}/${dt.month}';
  }

  String _formatFullDate(String iso) {
    final dt = DateTime.parse(iso);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        title: Text(t('Risk Trend', 'जोखिम ट्रेंड'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE91E8C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E8C)))
          : _screenings.length < 2
              ? _buildNotEnoughData(sw)
              : _buildGraph(sw),
    );
  }

  Widget _buildNotEnoughData(double sw) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(sw * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart,
                size: sw * 0.2, color: Colors.pink.shade100),
            const SizedBox(height: 20),
            Text(
              t('Not enough data yet', 'अभी पर्याप्त डेटा नहीं है'),
              style: TextStyle(
                  fontSize: sw * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              t(
                'At least 2 screenings are needed to show a trend graph for ${widget.patientName}.',
                '${widget.patientName} के लिए ट्रेंड ग्राफ दिखाने हेतु कम से कम 2 जांच जरूरी हैं।',
              ),
              style: TextStyle(fontSize: sw * 0.033, color: Colors.black38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraph(double sw) {
    final scores =
        _screenings.map((s) => _saheliScore(s)).toList();
    final latest = scores.last;
    final first = scores.first;
    final trend = latest - first;

    return SingleChildScrollView(
      padding: EdgeInsets.all(sw * 0.045),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient header
          Container(
            padding: EdgeInsets.all(sw * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.pink.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Row(children: [
              CircleAvatar(
                radius: sw * 0.07,
                backgroundColor:
                    const Color(0xFFE91E8C).withOpacity(0.12),
                child: Text(
                  widget.patientName[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: sw * 0.065,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE91E8C)),
                ),
              ),
              SizedBox(width: sw * 0.04),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(widget.patientName,
                      style: TextStyle(
                          fontSize: sw * 0.045,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${_screenings.length} ${t('screenings', 'जांच')}  •  '
                    '${t('Latest', 'अंतिम')}: ${_formatFullDate(_screenings.last['screenedAt'])}',
                    style: TextStyle(
                        fontSize: sw * 0.03, color: Colors.black45),
                  ),
                ]),
              ),
            ]),
          ),

          SizedBox(height: sw * 0.045),

          // Trend summary chips
          Row(children: [
            _summaryChip(
              icon: Icons.trending_up,
              label: t('Latest Score', 'अंतिम स्कोर'),
              value: latest.toStringAsFixed(1),
              color: _scoreColor(latest),
              sw: sw,
            ),
            SizedBox(width: sw * 0.03),
            _summaryChip(
              icon: trend > 0
                  ? Icons.arrow_upward
                  : trend < 0
                      ? Icons.arrow_downward
                      : Icons.remove,
              label: t('Change', 'बदलाव'),
              value:
                  '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}',
              color: trend > 0.5
                  ? Colors.red
                  : trend < -0.5
                      ? Colors.green
                      : Colors.orange,
              sw: sw,
            ),
            SizedBox(width: sw * 0.03),
            _summaryChip(
              icon: Icons.medical_information_outlined,
              label: t('Status', 'स्थिति'),
              value: _scoreLabel(latest),
              color: _scoreColor(latest),
              sw: sw,
            ),
          ]),

          SizedBox(height: sw * 0.045),

          // The Line Graph
          Container(
            padding: EdgeInsets.fromLTRB(
                sw * 0.02, sw * 0.05, sw * 0.04, sw * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.pink.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Padding(
                padding: EdgeInsets.only(left: sw * 0.04),
                child: Text(
                  t('Saheli Score Over Time',
                      'समय के साथ सहेली स्कोर'),
                  style: TextStyle(
                      fontSize: sw * 0.038,
                      fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: sw * 0.04),
              AnimatedBuilder(
                animation: _drawAnim,
                builder: (context, _) => SizedBox(
                  height: sw * 0.65,
                  child: CustomPaint(
                    painter: _TrendLinePainter(
                      scores: scores,
                      dates: _screenings
                          .map((s) =>
                              _formatDate(s['screenedAt']))
                          .toList(),
                      progress: _drawAnim.value,
                      lineColor: const Color(0xFFE91E8C),
                    ),
                    size: Size(double.infinity, sw * 0.65),
                  ),
                ),
              ),
            ]),
          ),

          SizedBox(height: sw * 0.045),

          // Risk zone legend
          Container(
            padding: EdgeInsets.all(sw * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.pink.withOpacity(0.06),
                    blurRadius: 8)
              ],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(t('Risk Zones', 'जोखिम क्षेत्र'),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: sw * 0.036)),
              SizedBox(height: sw * 0.03),
              _legendRow('7.5 – 10', t('Severe Anaemia', 'गंभीर रक्ताल्पता'), Colors.red.shade600, sw),
              _legendRow('5.5 – 7.4', t('Moderate Anaemia', 'मध्यम रक्ताल्पता'), Colors.orange, sw),
              _legendRow('3.5 – 5.4', t('Mild Anaemia', 'हल्की रक्ताल्पता'), Colors.amber.shade700, sw),
              _legendRow('0 – 3.4', t('Normal', 'सामान्य'), Colors.green.shade600, sw),
            ]),
          ),

          SizedBox(height: sw * 0.045),

          // Per-visit timeline
          Text(t('Screening History', 'जांच इतिहास'),
              style: TextStyle(
                  fontSize: sw * 0.04, fontWeight: FontWeight.bold)),
          SizedBox(height: sw * 0.025),
          ..._screenings.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final score = scores[i];
            final color = _scoreColor(score);
            final isLast = i == _screenings.length - 1;
            return _timelineItem(s, score, color, i + 1, isLast, sw);
          }),

          SizedBox(height: sw * 0.04),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required double sw,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: sw * 0.03, horizontal: sw * 0.02),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: sw * 0.055),
          SizedBox(height: sw * 0.015),
          Text(value,
              style: TextStyle(
                  fontSize: sw * 0.042,
                  fontWeight: FontWeight.bold,
                  color: color)),
          SizedBox(height: sw * 0.008),
          Text(label,
              style: TextStyle(
                  fontSize: sw * 0.024, color: Colors.black45),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _legendRow(
      String range, String label, Color color, double sw) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: sw * 0.015),
      child: Row(children: [
        Container(
            width: sw * 0.04,
            height: sw * 0.04,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4))),
        SizedBox(width: sw * 0.03),
        Text(range,
            style: TextStyle(
                fontSize: sw * 0.032,
                fontWeight: FontWeight.w600,
                color: color)),
        SizedBox(width: sw * 0.02),
        Text(label,
            style: TextStyle(
                fontSize: sw * 0.03, color: Colors.black54)),
      ]),
    );
  }

  Widget _timelineItem(Map<String, dynamic> s, double score,
      Color color, int visitNum, bool isLast, double sw) {
    return IntrinsicHeight(
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        SizedBox(
          width: sw * 0.1,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
            Container(
              width: sw * 0.075,
              height: sw * 0.075,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle),
              child: Center(
                child: Text('$visitNum',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: sw * 0.032)),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                    width: 2,
                    color: Colors.grey.shade200,
                    margin:
                        EdgeInsets.symmetric(vertical: sw * 0.01)),
              ),
          ]),
        ),
        SizedBox(width: sw * 0.03),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: sw * 0.04),
            padding: EdgeInsets.all(sw * 0.035),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: color.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                Text(
                  _formatFullDate(s['screenedAt']),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: sw * 0.035),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: sw * 0.025,
                      vertical: sw * 0.01),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(20)),
                  child: Text(
                    '${score.toStringAsFixed(1)} / 10',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: sw * 0.032),
                  ),
                ),
              ]),
              SizedBox(height: sw * 0.015),
              Text(
                _scoreLabel(score),
                style: TextStyle(
                    color: color,
                    fontSize: sw * 0.032,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: sw * 0.008),
              Text(
                s['clinicalNote'],
                style: TextStyle(
                    fontSize: sw * 0.029,
                    color: Colors.black54,
                    height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Custom Line Chart Painter ──────────────────────────────────

class _TrendLinePainter extends CustomPainter {
  final List<double> scores;
  final List<String> dates;
  final double progress;
  final Color lineColor;

  _TrendLinePainter({
    required this.scores,
    required this.dates,
    required this.progress,
    required this.lineColor,
  });

  Color _zoneColor(double score) {
    if (score >= 7.5) return Colors.red.shade600;
    if (score >= 5.5) return Colors.orange;
    if (score >= 3.5) return Colors.amber.shade700;
    return Colors.green.shade600;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const double padLeft = 36;
    const double padRight = 16;
    const double padTop = 12;
    const double padBottom = 36;

    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;

    // ── Background zone bands ──
    final zones = [
      (0.0, 3.5, Colors.green.shade50),
      (3.5, 5.5, Colors.amber.shade50),
      (5.5, 7.5, Colors.orange.shade50),
      (7.5, 10.0, Colors.red.shade50),
    ];
    for (final z in zones) {
      final top = padTop + chartH * (1 - z.$2 / 10);
      final bot = padTop + chartH * (1 - z.$1 / 10);
      canvas.drawRect(
        Rect.fromLTRB(padLeft, top, padLeft + chartW, bot),
        Paint()..color = z.$3,
      );
    }

    // ── Grid lines & Y labels ──
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
        color: Colors.grey.shade500,
        fontSize: 9,
        fontWeight: FontWeight.w500);

    for (int y = 0; y <= 10; y += 2) {
      final dy = padTop + chartH * (1 - y / 10);
      canvas.drawLine(
          Offset(padLeft, dy), Offset(padLeft + chartW, dy), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '$y', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(padLeft - tp.width - 4, dy - tp.height / 2));
    }

    // ── Data points & line ──
    final n = scores.length;
    List<Offset> points = [];
    for (int i = 0; i < n; i++) {
      final x = padLeft + (n == 1 ? chartW / 2 : chartW * i / (n - 1));
      final y = padTop + chartH * (1 - scores[i] / 10);
      points.add(Offset(x, y));
    }

    // Animated clip — draw only up to `progress` along the path
    final totalPoints = (progress * (n - 1)).clamp(0.0, (n - 1).toDouble());
    final fullIdx = totalPoints.floor();
    final frac = totalPoints - fullIdx;

    // Shadow under line
    if (points.length > 1) {
      final shadowPath = Path();
      shadowPath.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i <= fullIdx && i < points.length; i++) {
        shadowPath.lineTo(points[i].dx, points[i].dy);
      }
      if (fullIdx < points.length - 1 && frac > 0) {
        final interX = lerpDouble(
            points[fullIdx].dx, points[fullIdx + 1].dx, frac)!;
        final interY = lerpDouble(
            points[fullIdx].dy, points[fullIdx + 1].dy, frac)!;
        shadowPath.lineTo(interX, interY);
      }
      // Fill gradient
      final fillPath = Path.from(shadowPath);
      fillPath.lineTo(
          progress < 1.0 && fullIdx < points.length - 1
              ? lerpDouble(points[fullIdx].dx,
                  points[fullIdx + 1].dx, frac)!
              : points[min(fullIdx, points.length - 1)].dx,
          padTop + chartH);
      fillPath.lineTo(points[0].dx, padTop + chartH);
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withOpacity(0.18),
              lineColor.withOpacity(0.02),
            ],
          ).createShader(
              Rect.fromLTWH(padLeft, padTop, chartW, chartH)),
      );

      // Main line
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(shadowPath, linePaint);
    }

    // Dots
    for (int i = 0; i <= fullIdx && i < points.length; i++) {
      final dotColor = _zoneColor(scores[i]);
      // Outer ring
      canvas.drawCircle(
          points[i],
          7,
          Paint()
            ..color = dotColor.withOpacity(0.2)
            ..style = PaintingStyle.fill);
      // Inner dot
      canvas.drawCircle(
          points[i],
          4.5,
          Paint()
            ..color = dotColor
            ..style = PaintingStyle.fill);
      // White center
      canvas.drawCircle(
          points[i],
          2,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill);

      // Score label above dot
      final scoreTp = TextPainter(
        text: TextSpan(
            text: scores[i].toStringAsFixed(1),
            style: TextStyle(
                color: dotColor,
                fontSize: 9.5,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      scoreTp.paint(canvas,
          Offset(points[i].dx - scoreTp.width / 2, points[i].dy - 20));

      // Date label below axis
      final dateTp = TextPainter(
        text: TextSpan(text: dates[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      dateTp.paint(
          canvas,
          Offset(points[i].dx - dateTp.width / 2,
              padTop + chartH + 6));
    }
  }

  double? lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(_TrendLinePainter old) =>
      old.progress != progress || old.scores != scores;
}