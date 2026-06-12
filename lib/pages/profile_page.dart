import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/emotion_result.dart';
import '../models/quota_status.dart';
import '../services/auth_service.dart';
import '../services/quota_service.dart';
import '../services/theme_service.dart';
import '../services/timeline_service.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'forgot_password_page.dart';
import 'login_page.dart';
import 'reset_password_page.dart';
import 'support_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  final _timelineService = TimelineService();
  final _quotaService = QuotaService();

  UserModel? _user;
  int _totalScans = 0;
  String _topEmotion = '-';
  String _topEmotionKey = 'neutral';
  QuotaStatus? _quota;
  bool _pageLoading = true;
  bool _processingAction = false;
  bool _notificationsEnabled = true;

  static const Map<String, String> _apiEndpoints = {
    'Text': 'https://graduation-project-website-eight.vercel.app/text/emotion/text_model',
    'Audio': 'https://graduation-project-website-eight.vercel.app/audio/emotion/audio_model',
    'Photo': 'https://graduation-project-website-eight.vercel.app/image/emotion/image',
    'Video': 'https://graduation-project-website-eight.vercel.app/video/emotion/video',
  };

  static const Set<String> _connectedEndpoints = {'Text', 'Audio', 'Photo', 'Video'};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _pageLoading = true);
    }

    final user = await _authService.getCurrentUser();
    final history = await _timelineService.getHistory();
    final counts = await _timelineService.getEmotionCounts(
      cachedHistory: history,
    );

    String top = '-';
    String topKeyStr = 'neutral';
    if (counts.isNotEmpty) {
      final topKey = counts.entries.reduce(
            (a, b) => a.value >= b.value ? a : b,
      ).key;
      topKeyStr = topKey;
      top = formatEmotionLabel(topKey);
    }

    if (!mounted) return;

    // Load quota (non-blocking — hide if unavailable)
    QuotaStatus? quota;
    try {
      quota = await _quotaService.getQuota();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _user = user;
      _totalScans = history.length;
      _topEmotion = top;
      _topEmotionKey = topKeyStr;
      _quota = quota;
      _pageLoading = false;
    });
  }

  Future<void> _requestPasswordReset() async {
    final email = _user?.email ?? '';
    if (email.trim().isEmpty) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
      );
      return;
    }

    setState(() => _processingAction = true);

    final result = await _authService.forgotPassword(email.trim());

    if (!mounted) return;

    setState(() => _processingAction = false);

    if (result['success'] == true) {
      showAppSnackbar(context, 'Reset code sent to your email');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(email: email.trim()),
        ),
      );
    } else {
      showAppSnackbar(
        context,
        result['message']?.toString() ?? 'Failed to send reset code',
        isError: true,
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Sign out',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _authService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Delete account',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This action is permanent and cannot be undone. All your analyses, alerts, and account data will be removed.',
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingAction = true);
    final result = await _authService.deleteAccount();

    if (!mounted) return;

    setState(() => _processingAction = false);

    if (result['success'] == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (_) => false,
      );
    } else {
      showAppSnackbar(
        context,
        result['message']?.toString() ?? 'Failed to delete account',
        isError: true,
      );
    }
  }

  Color _getAvatarColor(String? colorString) {
    if (colorString == null || colorString.isEmpty || colorString == 'null') {
      return AppColors.primary;
    }

    try {
      return Color(int.parse(colorString));
    } catch (_) {
      return AppColors.primary;
    }
  }

  String _initialForName(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, currentTheme, _) {
        final normalizedTheme = currentTheme.toLowerCase();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: _processingAction ? null : _logout,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
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
                top: 100,
                left: -50,
                child: IgnorePointer(
                  child: Container(
                    width: 180,
                    height: 180,
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
                onRefresh: _loadData,
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: _pageLoading
                      ? _buildLoadingState()
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileHero()
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(
                        begin: -0.05,
                        end: 0,
                        curve: Curves.easeOutCubic,
                      ),
                      const SizedBox(height: 18),
                      _buildStatsRow()
                          .animate()
                          .fadeIn(delay: 80.ms, duration: 350.ms)
                          .slideY(
                        begin: 0.04,
                        end: 0,
                        curve: Curves.easeOutCubic,
                      ),
                      if (_quota != null) ...[
                        const SizedBox(height: 16),
                        _buildWeeklyUsageCard()
                            .animate()
                            .fadeIn(delay: 120.ms, duration: 350.ms)
                            .slideY(
                          begin: 0.04,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                      ],
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: 'Account',
                        subtitle:
                        'Manage profile details, security, and personal preferences.',
                        children: [
                          _SettingsItem(
                            icon: Icons.person_outline_rounded,
                            label: 'Edit Profile',
                            onTap: _showEditProfile,
                          ),
                          _SettingsItem(
                            icon: Icons.lock_outline_rounded,
                            label: 'Reset Password',
                            onTap: _processingAction
                                ? null
                                : _requestPasswordReset,
                          ),
                          _SettingsItem(
                            icon: Icons.notifications_outlined,
                            label: 'Notifications',
                            trailing: Switch.adaptive(
                              value: _notificationsEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _notificationsEnabled = value;
                                });
                              },
                              activeTrackColor: AppColors.primary,
                            ),
                          ),
                          _SettingsItem(
                            icon: Icons.contact_support_outlined,
                            label: 'Contact Support',
                            onTap: () {
                              Navigator.push(
                                context,
                                AppRoute.slide(const SupportPage()),
                              );
                            },
                          ),
                          _SettingsItem(
                            icon: Icons.delete_outline_rounded,
                            iconColor: AppColors.error,
                            label: 'Delete Account',
                            labelColor: AppColors.error,
                            onTap: _processingAction
                                ? null
                                : _confirmDeleteAccount,
                          ),
                        ],
                      )
                          .animate()
                          .fadeIn(delay: 140.ms, duration: 350.ms)
                          .slideY(
                        begin: 0.04,
                        end: 0,
                        curve: Curves.easeOutCubic,
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Appearance',
                        subtitle:
                        'Choose the visual style that fits your workflow.',
                        childPadding: EdgeInsets.zero,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              16,
                            ),
                            child: Row(
                              children: [
                                _ThemeCard(
                                  themeName: 'Light',
                                  primary: const Color(0xFF5B5FEF),
                                  accent: const Color(0xFF14B8A6),
                                  background: const Color(0xFFF6F8FC),
                                  isSelected: normalizedTheme == 'light',
                                  onTap: () =>
                                      ThemeService.setTheme('Light'),
                                ),
                                const SizedBox(width: 12),
                                _ThemeCard(
                                  themeName: 'Dark',
                                  primary: const Color(0xFF7C84FF),
                                  accent: const Color(0xFF8B5CF6),
                                  background: const Color(0xFF0B1020),
                                  isSelected: normalizedTheme == 'dark',
                                  onTap: () =>
                                      ThemeService.setTheme('Dark'),
                                ),
                                const SizedBox(width: 12),
                                _ThemeCard(
                                  themeName: 'Ocean',
                                  primary: const Color(0xFF0077B6),
                                  accent: const Color(0xFF00B4D8),
                                  background: const Color(0xFFF2FBFD),
                                  isSelected: normalizedTheme == 'ocean',
                                  onTap: () =>
                                      ThemeService.setTheme('Ocean'),
                                ),
                                const SizedBox(width: 12),
                                _ThemeCard(
                                  themeName: 'Sunset',
                                  primary: const Color(0xFFE76F51),
                                  accent: const Color(0xFFF4A261),
                                  background: const Color(0xFFFFF8F4),
                                  isSelected:
                                  normalizedTheme == 'sunset',
                                  onTap: () =>
                                      ThemeService.setTheme('Sunset'),
                                ),
                                const SizedBox(width: 12),
                                _ThemeCard(
                                  themeName: 'Forest',
                                  primary: const Color(0xFF2D6A4F),
                                  accent: const Color(0xFF40916C),
                                  background: const Color(0xFFF4FBF6),
                                  isSelected:
                                  normalizedTheme == 'forest',
                                  onTap: () =>
                                      ThemeService.setTheme('Forest'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 350.ms)
                          .slideY(
                        begin: 0.04,
                        end: 0,
                        curve: Curves.easeOutCubic,
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Achievements',
                        subtitle: 'Milestones from your emotional journey.',
                        children: [
                          SizedBox(
                            height: 100,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _AchievementBadge(
                                  emoji: '🌱',
                                  title: 'First Steps',
                                  condition: '1 scan',
                                  unlocked: _totalScans >= 1,
                                ),
                                _AchievementBadge(
                                  emoji: '🔥',
                                  title: 'On Fire',
                                  condition: '10 scans',
                                  unlocked: _totalScans >= 10,
                                ),
                                _AchievementBadge(
                                  emoji: '⭐',
                                  title: 'Star Analyst',
                                  condition: '25 scans',
                                  unlocked: _totalScans >= 25,
                                ),
                                _AchievementBadge(
                                  emoji: '💎',
                                  title: 'Diamond Mind',
                                  condition: '50 scans',
                                  unlocked: _totalScans >= 50,
                                ),
                                _AchievementBadge(
                                  emoji: '🏆',
                                  title: 'Champion',
                                  condition: '100 scans',
                                  unlocked: _totalScans >= 100,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                          .animate()
                          .fadeIn(delay: 350.ms, duration: 350.ms)
                          .slideY(
                        begin: 0.04,
                        end: 0,
                        curve: Curves.easeOutCubic,
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'API Status',
                        subtitle:
                        'Check which analysis modalities are connected to live endpoints.',
                        children: [
                          _ApiStatusItem(
                            icon: Icons.text_fields_rounded,
                            label: 'Text',
                            endpoint: _apiEndpoints['Text']!,
                            isConnected:
                            _connectedEndpoints.contains('Text'),
                            onTap: () => _showEndpointDetail(
                              'Text',
                              _apiEndpoints['Text']!,
                              _connectedEndpoints.contains('Text'),
                            ),
                          ),
                          _ApiStatusItem(
                            icon: Icons.mic_rounded,
                            label: 'Audio',
                            endpoint: _apiEndpoints['Audio']!,
                            isConnected:
                            _connectedEndpoints.contains('Audio'),
                            onTap: () => _showEndpointDetail(
                              'Audio',
                              _apiEndpoints['Audio']!,
                              _connectedEndpoints.contains('Audio'),
                            ),
                          ),
                          _ApiStatusItem(
                            icon: Icons.photo_camera_rounded,
                            label: 'Photo',
                            endpoint: _apiEndpoints['Photo']!,
                            isConnected:
                            _connectedEndpoints.contains('Photo'),
                            onTap: () => _showEndpointDetail(
                              'Photo',
                              _apiEndpoints['Photo']!,
                              _connectedEndpoints.contains('Photo'),
                            ),
                          ),
                          _ApiStatusItem(
                            icon: Icons.videocam_rounded,
                            label: 'Video',
                            endpoint: _apiEndpoints['Video']!,
                            isConnected:
                            _connectedEndpoints.contains('Video'),
                            onTap: () => _showEndpointDetail(
                              'Video',
                              _apiEndpoints['Video']!,
                              _connectedEndpoints.contains('Video'),
                            ),
                          ),
                        ],
                      )
                          .animate()
                          .fadeIn(delay: 260.ms, duration: 350.ms)
                          .slideY(
                        begin: 0.04,
                        end: 0,
                        curve: Curves.easeOutCubic,
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'About',
                        subtitle:
                        'Application information and account exit actions.',
                        children: [
                          _SettingsItem(
                            icon: Icons.info_outline_rounded,
                            label: 'App Version',
                            trailing: Text(
                              '1.0.0',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _SettingsItem(
                            icon: Icons.logout_rounded,
                            iconColor: AppColors.error,
                            label: 'Sign Out',
                            labelColor: AppColors.error,
                            onTap:
                            _processingAction ? null : _logout,
                          ),
                        ],
                      )
                          .animate()
                          .fadeIn(delay: 320.ms, duration: 350.ms)
                          .slideY(
                        begin: 0.04,
                        end: 0,
                        curve: Curves.easeOutCubic,
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'EMOTRA v1.0.0',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Designed for clear and modern emotion insights',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 380.ms, duration: 350.ms),
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

  Widget _buildProfileHero() {
    final avatarColor = _getAvatarColor(_user?.avatarUrl);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            avatarColor,
            avatarColor.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: avatarColor.withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Center(
              child: Text(
                _initialForName(_user?.name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?.name ?? 'Unknown User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _user?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    'Personal workspace',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _ProfileStat(
          label: 'Total Scans',
          value: _totalScans.toString(),
          icon: Icons.analytics_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        _ProfileStat(
          label: 'Top Emotion',
          value: _topEmotion,
          icon: Icons.emoji_emotions_rounded,
          color: emotionColor(_topEmotionKey),
          emoji: emotionEmoji(_topEmotionKey),
        ),
      ],
    );
  }

  Widget _buildWeeklyUsageCard() {
    final q = _quota!;
    final weekLabel = 'Week of ${DateFormat('MMM d').format(q.weekStartDate)}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Usage',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$weekLabel · Resets Monday',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          QuotaProgressBar(
            label: 'Text',
            icon: Icons.text_fields_rounded,
            status: q.text,
            unit: 'tokens',
          ),
          QuotaProgressBar(
            label: 'Audio',
            icon: Icons.mic_rounded,
            status: q.audio,
            unit: 'seconds',
          ),
          QuotaProgressBar(
            label: 'Photo',
            icon: Icons.photo_camera_rounded,
            status: q.image,
            unit: 'images',
          ),
          QuotaProgressBar(
            label: 'Video',
            icon: Icons.videocam_rounded,
            status: q.video,
            unit: 'seconds',
          ),
        ],
      ),
    );
  }


  Widget _buildLoadingState() {
    return Column(
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.borderSoft),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _loadingBox(height: 110)),
            const SizedBox(width: 12),
            Expanded(child: _loadingBox(height: 110)),
          ],
        ),
        const SizedBox(height: 16),
        _loadingBox(height: 220),
        const SizedBox(height: 16),
        _loadingBox(height: 180),
        const SizedBox(height: 16),
        _loadingBox(height: 220),
      ],
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: 0.55, end: 1, duration: 900.ms);
  }

  Widget _loadingBox({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
    );
  }

  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _user?.name ?? '');
    final emailCtrl = TextEditingController(text: _user?.email ?? '');

    final swatches = [
      const Color(0xFF5B5FEF),
      const Color(0xFFE53E3E),
      const Color(0xFF48BB78),
      const Color(0xFFED8936),
      const Color(0xFF9F7AEA),
      const Color(0xFF4A90D9),
    ];

    bool isSaving = false;
    Color selectedColor = _getAvatarColor(_user?.avatarUrl);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final textTheme = Theme.of(context).textTheme;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Edit Profile',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Update your personal details and avatar appearance.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        hintText: 'Enter your full name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        hintText: 'you@example.com',
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Avatar Background',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: swatches.map((color) {
                        final isSelected =
                            selectedColor.toARGB32() == color.toARGB32();

                        return GestureDetector(
                          onTap: () {
                            setModalState(() => selectedColor = color);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.22),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: 'Save Changes',
                      loading: isSaving,
                      onTap: isSaving
                          ? null
                          : () async {
                        setModalState(() => isSaving = true);

                        try {
                          final email = emailCtrl.text.trim();
                          final name = nameCtrl.text.trim();

                          if (name.isEmpty) {
                            throw 'Please enter your name';
                          }
                          if (email.isEmpty || !email.contains('@')) {
                            throw 'Please enter a valid email address';
                          }

                          final success = await _authService.saveProfile(
                            name,
                            selectedColor.toARGB32().toString(),
                            email,
                          );

                          if (!context.mounted) return;

                          if (success) {
                            await _loadData();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            showAppSnackbar(
                              context,
                              'Profile updated successfully',
                            );
                          } else {
                            if (!context.mounted) return;
                            showAppSnackbar(
                              context,
                              'Failed to update profile',
                              isError: true,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showAppSnackbar(
                              context,
                              'Error updating profile: $e',
                              isError: true,
                            );
                          }
                        } finally {
                          if (context.mounted) {
                            setModalState(() => isSaving = false);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      nameCtrl.dispose();
      emailCtrl.dispose();
    });
  }

  void _showEndpointDetail(String type, String endpoint, bool isConnected) {
    final statusColor = isConnected ? AppColors.success : AppColors.warning;
    final statusIcon = isConnected
        ? Icons.check_circle_rounded
        : Icons.info_outline_rounded;
    final statusLabel = isConnected ? 'Connected' : 'Simulated';

    final bool isMicroservice = type == 'Text' || type == 'Audio';
    final String serviceType = isMicroservice
        ? 'Hybrid (Vercel AI + Main Backend)'
        : 'Local Simulation';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$type API · $statusLabel',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'SERVICE TYPE',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                serviceType,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'ENDPOINT',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Text(
                  endpoint,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isMicroservice
                    ? 'This modality uses a high-performance Python AI microservice hosted on Vercel for inference, with results synchronized to our main ASP.NET Core backend.'
                    : 'This modality currently runs localized analysis simulations. The backend API for this specific type is pending production deployment.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Close',
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final String themeName;
  final Color primary;
  final Color accent;
  final Color background;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.themeName,
    required this.primary,
    required this.accent,
    required this.background,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double width = 142;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? primary : AppColors.borderSoft,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: primary.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ]
              : AppTheme.softShadow,
        ),
        child: Column(
          children: [
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSoft),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Mini status bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, accent],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Row(
                        children: [
                          // Mini sidebar / card
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Container(
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  Container(
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Mini content area
                          Expanded(
                            flex: 3,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 4,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Container(
                                  height: 4,
                                  width: 28,
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.40),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    themeName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: primary,
                    size: 16,
                  ),
              ],
            ),
          ],
        ),
      ).animate(target: isSelected ? 1 : 0).scale(
        begin: const Offset(1, 1),
        end: const Offset(1.03, 1.03),
        duration: 180.ms,
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class _ApiStatusItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String endpoint;
  final bool isConnected;
  final VoidCallback onTap;

  const _ApiStatusItem({
    required this.icon,
    required this.label,
    required this.endpoint,
    required this.onTap,
    this.isConnected = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isConnected ? AppColors.success : AppColors.warning;
    final statusLabel = isConnected ? 'Connected' : 'Simulated';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Icon(
                icon,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label API',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    endpoint.replaceFirst(
                      'https://emotion-detection.runasp.net',
                      '…',
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? emoji;

  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          gradient: LinearGradient(
            colors: [
              AppColors.surface,
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            if (emoji != null)
              Text(
                emoji!,
                style: const TextStyle(fontSize: 24),
              )
            else
              Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry childPadding;

  const _SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
    this.childPadding = const EdgeInsets.fromLTRB(0, 0, 0, 4),
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: SectionHeader(
              title: title,
              subtitle: subtitle,
            ),
          ),
          Padding(
            padding: childPadding,
            child: Column(
              children: List.generate(children.length, (index) {
                final isLast = index == children.length - 1;
                return Column(
                  children: [
                    children[index],
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(color: AppColors.borderSoft, height: 1),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null || trailing != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor ?? AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: labelColor ?? AppColors.textPrimary,
                  ),
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final String emoji;
  final String title;
  final String condition;
  final bool unlocked;

  const _AchievementBadge({
    required this.emoji,
    required this.title,
    required this.condition,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.borderSoft,
          width: unlocked ? 1.5 : 1,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            unlocked ? emoji : '🔒',
            style: TextStyle(
              fontSize: unlocked ? 24 : 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: unlocked ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            condition,
            style: TextStyle(
              fontSize: 9.5,
              color: unlocked ? AppColors.primary : AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}