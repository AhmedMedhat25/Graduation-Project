import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/timeline_service.dart';
import '../services/theme_service.dart';
import '../services/api_client.dart';
import '../models/emotion_result.dart';
import '../theme.dart';
import 'login_page.dart';
import 'reset_password_page.dart';
import 'forgot_password_page.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ════════════════════════════════════════════════════════════
//  PROFILE PAGE
// ════════════════════════════════════════════════════════════
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  final _timelineService = TimelineService();

  UserModel? _user;
  int _totalScans = 0;
  String _topEmotion = '-';
  bool _loading = true;
  bool _notificationsEnabled = true;

  // Real API endpoints — shown in the API status section
  static const _apiEndpoints = {
    'Text': '${ApiClient.baseUrl}/analysis/text',
    'Audio': '${ApiClient.baseUrl}/analysis/audio',
    'Photo': 'Simulated (no API endpoint)',
    'Video': 'Simulated (no API endpoint)',
  };

  // Track which endpoints are truly connected vs simulated
  static const _connectedEndpoints = {'Text', 'Audio'};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUser();
    final history = await _timelineService.getHistory();
    final counts = await _timelineService.getEmotionCounts();

    String top = '-';
    if (counts.isNotEmpty) {
      top = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      top = top.isNotEmpty ? top[0].toUpperCase() + top.substring(1) : '-';
    }

    if (mounted) {
      setState(() {
        _user = user;
        _totalScans = history.length;
        _topEmotion = top;
        _loading = false;
      });
    }
  }

  Future<void> _requestPasswordReset() async {
    if (_user?.email == null || _user!.email.isEmpty) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage()));
      }
      return;
    }
    
    setState(() => _loading = true);
    final result = await _authService.forgotPassword(_user!.email);
    
    if (!mounted) return;
    setState(() => _loading = false);
    
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset code sent to your email')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(email: _user!.email),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to send reset code')),
      );
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _authService.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              }
            },
            child: Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, currentTheme, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              IconButton(
                icon: Icon(Icons.logout_rounded, color: AppColors.error),
                onPressed: _logout,
                tooltip: 'Sign out',
              ),
            ],
          ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Avatar + Name
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getAvatarColor(_user?.avatarUrl),
                      _getAvatarColor(_user?.avatarUrl).withValues(alpha: 0.7)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _getAvatarColor(_user?.avatarUrl).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _user?.name.isNotEmpty == true
                              ? _user!.name[0].toUpperCase()
                              : '?',
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user?.email ?? '',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Stats row
              Row(
                 children: [
                   _ProfileStat(
                       label: 'Total Scans',
                       value: _totalScans.toString(),
                       icon: Icons.analytics_rounded,
                       color: AppColors.primary),
                   const SizedBox(width: 12),
                   _ProfileStat(
                       label: 'Top Emotion',
                       value: _topEmotion,
                       icon: Icons.emoji_emotions_rounded,
                       color: AppColors.accent),
                 ],
               ),

              const SizedBox(height: 20),

              // Account Section
              _SectionCard(
                title: 'Account',
                children: [
                  _SettingsItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Edit Profile',
                    onTap: () => _showEditProfile(),
                  ),
                  _SettingsItem(
                    icon: Icons.lock_outline_rounded,
                    label: 'Reset Password',
                    onTap: _requestPasswordReset,
                  ),
                  _SettingsItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (val) {
                        setState(() {
                          _notificationsEnabled = val;
                        });
                      },
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  _SettingsItem(
                    icon: Icons.delete_outline_rounded,
                    iconColor: AppColors.error,
                    label: 'Delete Account',
                    labelColor: AppColors.error,
                    onTap: _confirmDeleteAccount,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Appearance Section
              _SectionCard(
                title: 'Appearance',
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _ThemeCard(
                          themeName: 'Light',
                          primary: const Color(0xFF2D3A8C),
                          accent: const Color(0xFF6C63FF),
                          background: const Color(0xFFF4F6FC),
                          isSelected: currentTheme == 'Light',
                          onTap: () => ThemeService.setTheme('Light'),
                        ),
                        const SizedBox(width: 12),
                        _ThemeCard(
                          themeName: 'Dark',
                          primary: const Color(0xFF6C63FF),
                          accent: const Color(0xFF2D3A8C),
                          background: const Color(0xFF0F121C),
                          isSelected: currentTheme == 'Dark',
                          onTap: () => ThemeService.setTheme('Dark'),
                        ),
                        const SizedBox(width: 12),
                        _ThemeCard(
                          themeName: 'Ocean',
                          primary: const Color(0xFF0077B6),
                          accent: const Color(0xFF03045E),
                          background: const Color(0xFFE0FBFC),
                          isSelected: currentTheme == 'Ocean',
                          onTap: () => ThemeService.setTheme('Ocean'),
                        ),
                        const SizedBox(width: 12),
                        _ThemeCard(
                          themeName: 'Sunset',
                          primary: const Color(0xFFE63946),
                          accent: const Color(0xFFF4A261),
                          background: const Color(0xFFFFF3E0),
                          isSelected: currentTheme == 'Sunset',
                          onTap: () => ThemeService.setTheme('Sunset'),
                        ),
                        const SizedBox(width: 12),
                        _ThemeCard(
                          themeName: 'Forest',
                          primary: const Color(0xFF2D6A4F),
                          accent: const Color(0xFF40916C),
                          background: const Color(0xFFE9F5E9),
                          isSelected: currentTheme == 'Forest',
                          onTap: () => ThemeService.setTheme('Forest'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // API Status Section — shows real connected endpoints
              _SectionCard(
                title: 'API Status',
                children: [
                  _ApiStatusItem(
                    icon: Icons.text_fields_rounded,
                    label: 'Text',
                    endpoint: _apiEndpoints['Text']!,
                    isConnected: _connectedEndpoints.contains('Text'),
                    onTap: () => _showEndpointDetail('Text',
                        _apiEndpoints['Text']!, _connectedEndpoints.contains('Text')),
                  ),
                  _ApiStatusItem(
                    icon: Icons.mic_rounded,
                    label: 'Audio',
                    endpoint: _apiEndpoints['Audio']!,
                    isConnected: _connectedEndpoints.contains('Audio'),
                    onTap: () => _showEndpointDetail('Audio',
                        _apiEndpoints['Audio']!, _connectedEndpoints.contains('Audio')),
                  ),
                  _ApiStatusItem(
                    icon: Icons.photo_camera_rounded,
                    label: 'Photo',
                    endpoint: _apiEndpoints['Photo']!,
                    isConnected: _connectedEndpoints.contains('Photo'),
                    onTap: () => _showEndpointDetail('Photo',
                        _apiEndpoints['Photo']!, _connectedEndpoints.contains('Photo')),
                  ),
                  _ApiStatusItem(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    endpoint: _apiEndpoints['Video']!,
                    isConnected: _connectedEndpoints.contains('Video'),
                    onTap: () => _showEndpointDetail('Video',
                        _apiEndpoints['Video']!, _connectedEndpoints.contains('Video')),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // About Section
              _SectionCard(
                title: 'About',
                children: [
                  _SettingsItem(
                    icon: Icons.info_outline_rounded,
                    label: 'App Version',
                    trailing: Text('1.0.0',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textLight)),
                  ),
                  _SettingsItem(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.error,
                    label: 'Sign Out',
                    labelColor: AppColors.error,
                    onTap: _logout,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'EMOTRA v1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              const SizedBox(height: 4),
              Text(
                'Made with ❤️',
                style: TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
              const SizedBox(height: 20),
            ].animate(interval: 60.ms).fadeIn(duration: 400.ms, curve: Curves.easeOut).slideY(begin: 0.1, curve: Curves.easeOut),
          ),
        ),
      ),
    );
  });
  }

  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _user?.name);
    final emailCtrl = TextEditingController(text: _user?.email);
    
    // Six swatches for avatar
    final swatches = [
      const Color(0xFF2D3A8C), // default primary
      const Color(0xFFE53E3E), // red
      const Color(0xFF48BB78), // green
      const Color(0xFFED8936), // orange
      const Color(0xFF9F7AEA), // purple
      const Color(0xFF4A90D9), // blue
    ];
    
    bool isSaving = false;
    Color selectedColor = _getAvatarColor(_user?.avatarUrl);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit Profile',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 20),
                  
                  // Editable Name
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Editable Email
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: AppColors.textDark),
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Avatar Color Picker
                  Text('Avatar Background', style: TextStyle(color: AppColors.textMid, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: swatches.map((color) {
                      final isSelected = selectedColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = color),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.textDark : Colors.transparent,
                              width: 3,
                            )
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        setModalState(() => isSaving = true);
                        try {
                          final email = emailCtrl.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                             throw 'Please enter a valid email address';
                          }

                          final success = await _authService.saveProfile(
                            nameCtrl.text.trim(), 
                            selectedColor.toARGB32().toString(),
                            email,
                          );
                          
                          if (success) {
                            await _loadData();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profile updated successfully')),
                              );
                              Navigator.pop(context);
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error updating profile: $e')),
                            );
                          }
                        } finally {
                          if (context.mounted) setModalState(() => isSaving = false);
                        }
                      },
                      child: isSaving 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showEndpointDetail(String type, String endpoint, bool isConnected) {
    final statusColor = isConnected ? AppColors.success : Colors.orange;
    final statusIcon = isConnected ? Icons.check_circle_rounded : Icons.info_outline_rounded;
    final statusLabel = isConnected ? 'Connected' : 'Simulated';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon,
                      color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text('$type API — $statusLabel',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Text(
                endpoint,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMid,
                    fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isConnected
                  ? 'Authentication: Bearer token (JWT)\nMethod: POST\nBase URL: ${ApiClient.baseUrl}'
                  : 'This modality runs client-side simulation.\nThe API does not yet support $type analysis.',
              style: TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.6),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent and cannot be undone. All your data, including analysis history and alerts, will be deleted.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      final result = await _authService.deleteAccount();
      if (!mounted) return;
      setState(() => _loading = false);

      if (result['success'] == true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to delete account')),
        );
      }
    }
  }
}

// ── Theme Card (Visual Gallery) ──────────────────────────────
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
    const double width = 140;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primary : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: primary.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Column(
          children: [
            // Palette Preview
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    left: -10,
                    top: -10,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: -10,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
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
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: primary, size: 16),
              ],
            ),
          ],
        ),
      ).animate(target: isSelected ? 1 : 0).scale(
        begin: const Offset(1, 1),
        end: const Offset(1.05, 1.05),
        duration: 200.ms,
        curve: Curves.easeOutBack,
      ),
    );
  }
}

// ── API Status Item ───────────────────────────────────────────
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
    final statusColor = isConnected ? AppColors.success : Colors.orange;
    final statusLabel = isConnected ? 'Connected' : 'Simulated';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textMid),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$label API',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark)),
                  Text(
                    endpoint.replaceFirst(
                        'https://emotion-detection.runasp.net', '…'),
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textLight),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w700)),
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

  const _ProfileStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          gradient: LinearGradient(
            colors: [
              AppColors.surface,
              color.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textDark)),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textLight,
                  letterSpacing: 0.5),
            ),
          ),
          ...children,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.textMid),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: labelColor ?? AppColors.textDark)),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
