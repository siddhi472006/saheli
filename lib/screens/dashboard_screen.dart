import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import 'patient_form_screen.dart';
import 'history_screen.dart';
import 'language_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String userType;
  final String language;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userType,
    required this.language,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _stats = {
    'total': 0,
    'high': 0,
    'moderate': 0,
    'low': 0
  };
  List<Map<String, dynamic>> _recentScreenings = [];
  bool _isLoading = true;

  bool get isHindi => widget.language == 'Hindi';
  String t(String english, String hindi) => isHindi ? hindi : english;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stats =
        await DatabaseHelper.instance.getStats(widget.userId);
    final screenings = await DatabaseHelper.instance
        .getScreeningsByUser(widget.userId);
    setState(() {
      _stats = stats;
      _recentScreenings = screenings.take(3).toList();
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LanguageScreen()),
      (route) => false,
    );
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'high':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'borderline':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  String _riskLabel(String level) {
    switch (level) {
      case 'high':
        return t('High Risk', 'उच्च जोखिम');
      case 'moderate':
        return t('Moderate', 'मध्यम जोखिम');
      case 'borderline':
        return t('Borderline', 'सीमारेखा');
      default:
        return t('Low Risk', 'कम जोखिम');
    }
  }

  IconData _riskIcon(String level) {
    switch (level) {
      case 'high':
        return Icons.error;
      case 'moderate':
        return Icons.warning_amber;
      case 'borderline':
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }

  String _formatDate(String isoDate) {
    final dt = DateTime.parse(isoDate);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Detail bottom sheet for a single recent screening ──────
  void _showScreeningDetail(Map<String, dynamic> s) {
    final level = s['riskLevel'] as String;
    final color = _riskColor(level);
    final symptoms = <String>[
      if (s['fatigue'] == 1) t('Fatigue', 'थकान'),
      if (s['dizziness'] == 1) t('Dizziness', 'चक्कर'),
      if (s['paleSkin'] == 1) t('Pale Skin', 'पीली त्वचा'),
      if (s['shortnessOfBreath'] == 1)
        t('Breathlessness', 'सांस की कमी'),
      if (s['heavyPeriods'] == 1) t('Heavy Periods', 'भारी माहवारी'),
      if (s['headache'] == 1) t('Headache', 'सिरदर्द'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF0F5),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_riskIcon(level), color: color, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(s['patientName'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    Text(
                      '${s['age']} ${t('yrs', 'वर्ष')}  •  ${_formatDate(s['screenedAt'])}',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54),
                    ),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_riskLabel(level),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
              ]),
              const SizedBox(height: 20),

              // Details card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.pink.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(children: [
                  _detailRow(t('Reason', 'कारण'), s['reason']),
                  if (s['pregnancyWeeks'] != null)
                    _detailRow(
                        t('Pregnancy Week', 'गर्भावस्था सप्ताह'),
                        'Week ${s['pregnancyWeeks']}'),
                  _detailRow(
                    t('Pallor Score', 'पीलापन स्कोर'),
                    '${((s['mlScore'] as num) * 100).toStringAsFixed(1)}%',
                  ),
                  _detailRow(
                    t('Risk Score', 'जोखिम स्कोर'),
                    '${((s['riskScore'] as num) * 100).toStringAsFixed(1)}%',
                  ),
                  if (symptoms.isNotEmpty)
                    _detailRow(t('Symptoms', 'लक्षण'),
                        symptoms.join(', ')),
                ]),
              ),
              const SizedBox(height: 12),

              // Clinical note
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(Icons.medical_services,
                      color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s['clinicalNote'],
                        style: const TextStyle(
                            fontSize: 13, height: 1.5)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // View full history button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryScreen(
                          userId: widget.userId,
                          language: widget.language,
                        ),
                      ),
                    );
                    _loadData();
                  },
                  icon: const Icon(Icons.history,
                      color: Color(0xFFE91E8C)),
                  label: Text(
                    t('View Full History', 'पूरी हिस्ट्री देखें'),
                    style: const TextStyle(
                        color: Color(0xFFE91E8C),
                        fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFFE91E8C), width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.black54, fontSize: 13))),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHealthWorker = widget.userType == 'HealthWorker';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFE91E8C)))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFFE91E8C),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E8C),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.favorite,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(t('Hello,', 'नमस्ते,'),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54)),
                                Text(widget.userName,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout,
                                color: Colors.grey),
                            tooltip: t('Logout', 'लॉगआउट'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E8C)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isHealthWorker
                              ? t('ASHA / Health Worker',
                                  'आशा / स्वास्थ्य कार्यकर्ता')
                              : t('Individual User',
                                  'व्यक्तिगत उपयोगकर्ता'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE91E8C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Stats ────────────────────────────────
                      Text(t('Screening Summary', 'जांच सारांश'),
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(
                            child: _statCard(
                                label: t('Total', 'कुल'),
                                value: '${_stats['total']}',
                                color: const Color(0xFFE91E8C),
                                icon: Icons.people_outline)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _statCard(
                                label: t('High Risk', 'उच्च जोखिम'),
                                value: '${_stats['high']}',
                                color: Colors.red,
                                icon: Icons.error_outline)),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _statCard(
                                label: t('Moderate', 'मध्यम'),
                                value: '${_stats['moderate']}',
                                color: Colors.orange,
                                icon: Icons.warning_amber_outlined)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _statCard(
                                label: t('Low Risk', 'कम जोखिम'),
                                value: '${_stats['low']}',
                                color: Colors.green,
                                icon: Icons.check_circle_outline)),
                      ]),

                      const SizedBox(height: 28),

                      // ── New Scan Button ──────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PatientFormScreen(
                                  userId: widget.userId,
                                  language: widget.language,
                                  userType: widget.userType,
                                  userName: widget.userName,
                                ),
                              ),
                            );
                            _loadData();
                          },
                          icon: const Icon(Icons.camera_alt,
                              size: 24),
                          label: Text(
                            isHealthWorker
                                ? t('+ New Patient Scan',
                                    '+ नई मरीज जांच')
                                : t('+ New Scan', '+ नई जांच'),
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFE91E8C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Recent Screenings ────────────────────
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              t('Recent Screenings', 'हाल की जांचें'),
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          // "View All" always visible once there's any history
                          if (_stats['total'] > 0)
                            TextButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HistoryScreen(
                                      userId: widget.userId,
                                      language: widget.language,
                                    ),
                                  ),
                                );
                                _loadData();
                              },
                              child: Text(
                                  t('View All', 'सभी देखें'),
                                  style: const TextStyle(
                                      color: Color(0xFFE91E8C),
                                      fontWeight:
                                          FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_recentScreenings.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 32),
                            child: Column(children: [
                              Icon(Icons.history,
                                  size: 56,
                                  color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                t(
                                    'No screenings yet.\nTap the button above to start!',
                                    'अभी तक कोई जांच नहीं।\nशुरू करने के लिए ऊपर बटन दबाएं!'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14),
                              ),
                            ]),
                          ),
                        )
                      else
                        // Each card is tappable — always, regardless of count
                        ..._recentScreenings
                            .map((s) => _screeningCard(s)),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _statCard({
  required String label,
  required String value,
  required Color color,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    ),
  );
}

  Widget _screeningCard(Map<String, dynamic> s) {
    final level = s['riskLevel'] as String;
    final color = _riskColor(level);
    return GestureDetector(
      onTap: () => _showScreeningDetail(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.pink.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_riskIcon(level), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(s['patientName'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                '${s['age']} ${t('yrs', 'वर्ष')}  •  ${s['reason']}  •  ${_formatDate(s['screenedAt'])}',
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54),
              ),
            ]),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_riskLabel(level),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                color: Colors.grey.shade400, size: 18),
          ]),
        ]),
      ),
    );
  }
}