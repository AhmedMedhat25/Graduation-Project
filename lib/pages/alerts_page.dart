import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/emotion_result.dart';
import '../services/alerts_service.dart';
import '../services/theme_service.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

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
    if (mounted) {
      setState(() => _loading = true);
    }

    final alerts = await _alertsService.getAlerts();

    if (!mounted) return;

    setState(() {
      _alerts = alerts;
      _loading = false;
    });
  }

  // ── Confirm delete via dialog ──
  Future<bool> _confirmDelete(EmotionAlert alert) async {
    HapticFeedback.mediumImpact();

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        final config = _alertVisualConfig(alert.type);

        return AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete alert?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alert preview
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: config.color.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      emotionEmoji(alert.emotion),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alert.title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'This alert will be permanently removed and cannot be recovered.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppColors.borderSoft),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppColors.error.withValues(alpha: 0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    return shouldDelete == true;
  }

  // ── Delete an alert ──
  Future<void> _deleteAlert(EmotionAlert alert) async {
    setState(() => _alerts.remove(alert));

    // Try cloud delete, then local cleanup
    await _alertsService.deleteAlert(alert.id);

    if (mounted) {
      showAppSnackbar(context, 'Alert deleted');
    }
  }

  // ── Mark single alert read ──
  Future<void> _markAsRead(EmotionAlert alert) async {
    if (alert.isRead) return;

    setState(() => alert.isRead = true);
    await _alertsService.markRead(alert.id);

    if (mounted) {
      showAppSnackbar(context, 'Marked as read');
    }
  }

  // ── Show alert details bottom sheet ──
  void _showAlertDetails(EmotionAlert alert) {
    HapticFeedback.lightImpact();

    // Auto-mark as read on open
    if (!alert.isRead) {
      setState(() => alert.isRead = true);
      _alertsService.markRead(alert.id);
    }

    final config = _alertVisualConfig(alert.type);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              // Gradient accent strip
              Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      config.color.withValues(alpha: 0.6),
                      config.color.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header: emoji + title + severity badge ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  config.color.withValues(alpha: 0.18),
                                  config.color.withValues(alpha: 0.06),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Text(
                                emotionEmoji(alert.emotion),
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert.title,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _SeverityBadge(
                                      severity: alert.severity ?? alert.type,
                                      color: config.color,
                                    ),
                                    if (alert.resolved == true) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.success
                                              .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 12,
                                              color: AppColors.success,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Resolved',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Message section ──
                      _DetailSection(
                        icon: Icons.message_outlined,
                        title: 'Message',
                        child: Text(
                          alert.message,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),

                      // ── Recommended action ──
                      if (alert.recommendedAction != null &&
                          alert.recommendedAction!.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _DetailSection(
                          icon: Icons.lightbulb_outline_rounded,
                          title: 'Recommended Action',
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.tips_and_updates_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    alert.recommendedAction!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.55,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // ── Metadata row ──
                      _DetailSection(
                        icon: Icons.info_outline_rounded,
                        title: 'Details',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaChip(
                              icon: Icons.schedule_rounded,
                              label: _formatTimestamp(alert.timestamp),
                            ),
                            if (alert.emotion.isNotEmpty)
                              _MetaChip(
                                icon: Icons.psychology_rounded,
                                label: alert.emotion[0].toUpperCase() +
                                    alert.emotion.substring(1),
                              ),
                            if (alert.analysisId != null)
                              _MetaChip(
                                icon: Icons.tag_rounded,
                                label: 'Analysis #${alert.analysisId}',
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 26),

                      // ── Action buttons ──
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              color: AppColors.error,
                              onTap: () async {
                                Navigator.pop(ctx);
                                final confirmed = await _confirmDelete(alert);
                                if (confirmed) _deleteAlert(alert);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (alert.resolved != true)
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.check_circle_outline_rounded,
                                label: 'Resolve',
                                color: AppColors.success,
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  await _alertsService
                                      .resolveAlert(alert.id);
                                  _load();
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime dt) {
    // Convert UTC timestamp to Cairo local time for display.
    final local = EmotionResult.toCairoTime(dt);
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${months[local.month]} ${local.day}, ${local.year} at $h:$m';
  }

  List<Object> _buildGroupedItems() {
    final items = <Object>[];
    String? lastDateKey;
    final now = EmotionResult.cairoNow();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final alert in _alerts) {
      // Convert UTC timestamp to Cairo local time before date comparison,
      // so "Today" / "Yesterday" matches the user's local clock.
      final local = EmotionResult.toCairoTime(alert.timestamp);
      final alertDate = DateTime(local.year, local.month, local.day);

      String dateKey;
      if (alertDate == today) {
        dateKey = 'Today';
      } else if (alertDate == yesterday) {
        dateKey = 'Yesterday';
      } else {
        final months = [
          '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        dateKey =
            '${months[alertDate.month]} ${alertDate.day}, ${alertDate.year}';
      }

      if (dateKey != lastDateKey) {
        items.add(dateKey);
        lastDateKey = dateKey;
      }
      items.add(alert);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, _, __) {
        final textTheme = Theme.of(context).textTheme;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSoft),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            leadingWidth: 64,
            title: Text(
              'Alerts',
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                Positioned(
                  top: -90,
                  right: -50,
                  child: IgnorePointer(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.12),
                            AppColors.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 80,
                  left: -60,
                  child: IgnorePointer(
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0.08),
                            AppColors.accent.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: _buildHeaderSummary(textTheme)
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(
                            begin: -0.05,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      if (_loading)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildLoadingState(textTheme),
                          ),
                        )
                      else if (_alerts.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                            child: AnimatedEmptyState(
                              icon: Icons.notifications_none_rounded,
                              title: 'No alerts yet',
                              subtitle:
                              'Alerts will appear here when notable emotional patterns are detected in your analyses.',
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          sliver: Builder(
                            builder: (context) {
                              // Build once; reuse for both builder and childCount.
                              final items = _buildGroupedItems();
                              return SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    if (index >= items.length) return null;
                                    final item = items[index];

                                    if (item is String) {
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          top: index == 0 ? 0 : 16,
                                          bottom: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                item,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Container(
                                                height: 1,
                                                color: AppColors.borderSoft,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ).animate().fadeIn(duration: 300.ms);
                                    }

                                    final alert = item as EmotionAlert;
                                    return Dismissible(
                                      key: ValueKey(
                                          'alert-${alert.id}-${alert.timestamp.millisecondsSinceEpoch}'),
                                      direction: DismissDirection.endToStart,
                                      confirmDismiss: (_) =>
                                          _confirmDelete(alert),
                                      onDismissed: (_) =>
                                          _deleteAlert(alert),
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding:
                                            const EdgeInsets.only(right: 24),
                                        margin:
                                            const EdgeInsets.symmetric(
                                                vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.error
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.delete_rounded,
                                              color: AppColors.error,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: AppColors.error,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      child: _AlertCard(
                                        alert: alert,
                                        onTap: () =>
                                            _showAlertDetails(alert),
                                        onMarkRead: () =>
                                            _markAsRead(alert),
                                      )
                                          .animate()
                                          .fadeIn(
                                        delay: (index * 50).ms,
                                        duration: 350.ms,
                                      )
                                          .slideY(
                                        begin: 0.05,
                                        end: 0,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    );
                                  },
                                  childCount: items.length,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSummary(TextTheme textTheme) {
    final unreadCount = _alerts.where((a) => !a.isRead).length;

    return PremiumCard(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(28),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Emotion Alerts',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _loading
                      ? 'Loading your latest notifications...'
                      : _alerts.isEmpty
                      ? 'You\'re all caught up. No active alerts right now.'
                      : '${_alerts.length} alert${_alerts.length == 1 ? '' : 's'} • Tap to view details, swipe to delete.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(TextTheme textTheme) {
    return Column(
      children: List.generate(
        3,
            (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 12,
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 180),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 10,
                      width: 90,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .fade(
          begin: 0.55,
          end: 1,
          duration: 900.ms,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// ALERT CARD — tappable, with unread indicator
// ═════════════════════════════════════════════════════════════

class _AlertCard extends StatelessWidget {
  final EmotionAlert alert;
  final VoidCallback? onTap;
  final VoidCallback? onMarkRead;

  const _AlertCard({
    required this.alert,
    this.onTap,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final config = _alertVisualConfig(alert.type);
    final Color accentColor = config.color;
    final Color borderColor = config.borderColor;
    final bool isUnread = !alert.isRead;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isUnread
              ? accentColor.withValues(alpha: 0.03)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isUnread
                ? accentColor.withValues(alpha: 0.30)
                : borderColor,
          ),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          children: [
            // Colored top accent bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji icon with unread dot
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withValues(alpha: 0.18),
                              accentColor.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            emotionEmoji(alert.emotion),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      // Unread dot
                      if (isUnread)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + severity badge
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                alert.title,
                                style:
                                    textTheme.titleMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: isUnread
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _SeverityBadge(
                              severity:
                                  alert.severity ?? alert.type,
                              color: accentColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Message
                        Text(
                          alert.message,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // Footer: timestamp + actions
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _timeAgo(alert.timestamp),
                              style:
                                  textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (isUnread && onMarkRead != null)
                              GestureDetector(
                                onTap: onMarkRead,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons
                                            .done_all_rounded,
                                        size: 12,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Mark read',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight:
                                              FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Tap-to-view chevron
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(dt.toUtc());

    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ═════════════════════════════════════════════════════════════
// SEVERITY BADGE
// ═════════════════════════════════════════════════════════════

class _SeverityBadge extends StatelessWidget {
  final String severity;
  final Color color;

  const _SeverityBadge({
    required this.severity,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String get _label {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'CRITICAL';
      case 'high':
      case 'warning':
        return 'HIGH';
      case 'medium':
      case 'info':
        return 'MEDIUM';
      case 'low':
      case 'positive':
        return 'LOW';
      default:
        return severity.toUpperCase();
    }
  }
}

// ═════════════════════════════════════════════════════════════
// DETAIL BOTTOM SHEET HELPERS
// ═════════════════════════════════════════════════════════════

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// ALERT VISUAL CONFIG
// ═════════════════════════════════════════════════════════════

class _AlertVisualConfig {
  final Color color;
  final Color borderColor;
  final String label;

  const _AlertVisualConfig({
    required this.color,
    required this.borderColor,
    required this.label,
  });
}

_AlertVisualConfig _alertVisualConfig(String type) {
  switch (type) {
    case 'critical':
      return _AlertVisualConfig(
        color: AppColors.error,
        borderColor: AppColors.error.withValues(alpha: 0.25),
        label: 'CRITICAL',
      );
    case 'warning':
      return _AlertVisualConfig(
        color: AppColors.warning,
        borderColor: AppColors.warning.withValues(alpha: 0.22),
        label: 'WARNING',
      );
    case 'positive':
      return _AlertVisualConfig(
        color: AppColors.success,
        borderColor: AppColors.success.withValues(alpha: 0.22),
        label: 'POSITIVE',
      );
    default:
      return _AlertVisualConfig(
        color: AppColors.secondary,
        borderColor: AppColors.secondary.withValues(alpha: 0.18),
        label: 'INFO',
      );
  }
}