import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/alerts_service.dart';
import '../theme.dart';
import '../services/theme_service.dart';
import '../widgets/shared_widgets.dart';

// ════════════════════════════════════════════════════════════
//  ALERTS PAGE
// ════════════════════════════════════════════════════════════
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final _alertsService = AlertsService();
  List<EmotionAlert> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final alerts = await _alertsService.getAlerts();
    await _alertsService.markAllRead();
    if (mounted) {
      setState(() {
      _alerts = alerts;
      _loading = false;
    });
    }
  }

  Future<void> _clearAll() async {
    await _alertsService.clearAlerts();
    if (mounted) setState(() => _alerts = []);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Alerts'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_alerts.isNotEmpty)
                TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Clear All Alerts'),
                      content: const Text(
                          'Are you sure you want to clear all alerts?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _clearAll();
                          },
                          child: const Text('Clear',
                              style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Clear all',
                      style: TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _alerts.isEmpty
                  ? const AnimatedEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No alerts yet',
                      subtitle: 'Alerts appear when notable emotions\nare detected in your analyses.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _alerts.length,
                        itemBuilder: (_, i) => _AlertCard(alert: _alerts[i])
                            .animate()
                            .fadeIn(delay: (i * 80).ms, duration: 400.ms)
                            .slideX(begin: 0.1, curve: Curves.easeOut),
                      ),
                    ),
        );
      },
    );
  }
}

// ── Single Alert Card ─────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final EmotionAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final cfg = _alertConfig(alert.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cfg['border'] as Color),
      ),
      child: Column(
        children: [
          // Colored top accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: cfg['color'] as Color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (cfg['color'] as Color).withValues(alpha: 0.2),
                        (cfg['color'] as Color).withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(emotionEmoji(alert.emotion),
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (cfg['color'] as Color)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cfg['label'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: cfg['color'] as Color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert.message,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMid, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _timeAgo(alert.timestamp),
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _alertConfig(String type) {
    switch (type) {
      case 'warning':
        return {
          'color': AppColors.warning,
          'border': AppColors.warning.withValues(alpha: 0.25),
          'label': 'WARNING',
        };
      case 'positive':
        return {
          'color': AppColors.success,
          'border': AppColors.success.withValues(alpha: 0.25),
          'label': 'POSITIVE',
        };
      default:
        return {
          'color': AppColors.secondary,
          'border': AppColors.secondary.withValues(alpha: 0.2),
          'label': 'INFO',
        };
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
