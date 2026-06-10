import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'login_page.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();

    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _authService.forgotPassword(_emailCtrl.text.trim());

    if (!mounted) return;

    setState(() => _loading = false);

    if (result['success'] == true) {
      setState(() => _sent = true);
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Failed to send reset link';
      });
    }
  }

  void _goToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  void _goToResetPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordPage(email: _emailCtrl.text.trim()),
      ),
    );
  }

  void _tryAgain() {
    setState(() {
      _sent = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: InkWell(
              onTap: _goToLogin,
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
                          AppColors.primary.withValues(alpha: 0.14),
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
                          AppColors.accent.withValues(alpha: 0.10),
                          AppColors.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: _sent
                    ? _buildSuccessState(textTheme)
                    : _buildFormState(textTheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormState(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          textTheme,
          icon: Icons.lock_reset_rounded,
          title: 'Forgot password?',
          subtitle:
          'Enter your email address and we’ll help you regain access to your account securely.',
        ),
        const SizedBox(height: 28),
        PremiumCard(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reset via email',
                style: textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We’ll send a reset code to your inbox so you can create a new password.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.email,
                        AutofillHints.username,
                      ],
                      onFieldSubmitted: (_) => _loading ? null : _sendResetLink(),
                      decoration: InputDecoration(
                        labelText: 'Email address',
                        hintText: 'you@example.com',
                        prefixIcon: Icon(
                          Icons.mail_outline_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Enter your email address';
                        if (!email.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Send Reset Link',
                      onTap: _sendResetLink,
                      loading: _loading,
                      icon: Icons.send_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'If the email exists in our system, you’ll receive reset instructions shortly.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 100.ms, duration: 450.ms)
            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: 22),
        _buildFooter(
          textTheme,
          prefix: 'Remember your password?',
          action: 'Sign In',
          onTap: _goToLogin,
        ),
      ],
    );
  }

  Widget _buildSuccessState(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          textTheme,
          icon: Icons.mark_email_read_rounded,
          title: 'Check your email',
          subtitle:
          'We’ve sent reset instructions to the address below so you can continue securely.',
          isSuccess: true,
        ),
        const SizedBox(height: 28),
        PremiumCard(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Email sent',
                style: textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Icon(
                        Icons.alternate_email_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _emailCtrl.text.trim(),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Check your spam or promotions folder if the email does not appear in your inbox.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Enter Reset Code',
                onTap: _goToResetPage,
                icon: Icons.vpn_key_rounded,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _tryAgain,
                child: const Text('Didn’t receive email? Try again'),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 100.ms, duration: 450.ms)
            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: 22),
        _buildFooter(
          textTheme,
          prefix: 'Want to go back?',
          action: 'Sign In',
          onTap: _goToLogin,
        ),
      ],
    );
  }

  Widget _buildHeader(
      TextTheme textTheme, {
        required IconData icon,
        required String title,
        required String subtitle,
        bool isSuccess = false,
      }) {
    final accentColor = isSuccess ? AppColors.success : AppColors.primary;

    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: isSuccess
                ? AppColors.success.withValues(alpha: 0.12)
                : null,
            gradient: isSuccess ? null : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            border: isSuccess
                ? Border.all(color: AppColors.success.withValues(alpha: 0.18))
                : null,
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.20),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isSuccess ? AppColors.success : Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.55,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 450.ms)
        .slideY(begin: -0.06, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildFooter(
      TextTheme textTheme, {
        required String prefix,
        required String action,
        required VoidCallback onTap,
      }) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(
            prefix,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              action,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 220.ms, duration: 450.ms);
  }
}