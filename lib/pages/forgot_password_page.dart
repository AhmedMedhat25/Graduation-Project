import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'login_page.dart';
import 'reset_password_page.dart';

// ════════════════════════════════════════════════════════════
//  FORGOT PASSWORD PAGE
// ════════════════════════════════════════════════════════════
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
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _authService.forgotPassword(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success']) {
      setState(() => _sent = true);
    } else {
      setState(() => _error = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textDark, size: 18),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _sent ? _buildSuccessState() : _buildFormState(),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // Icon
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_reset_rounded,
                color: AppColors.primary, size: 40),
          ),
        ),

        const SizedBox(height: 24),

        Center(
          child: Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Center(
          child: Text(
            'Enter your email address and we\'ll send you\na link to reset your password.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textLight, height: 1.5),
          ),
        ),

        const SizedBox(height: 36),

        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
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

        const SizedBox(height: 24),

        // Back to login
        Center(
          child: GestureDetector(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
              }
            },
            child: RichText(
              text: TextSpan(
                text: 'Remember your password? ',
                style: TextStyle(color: AppColors.textMid, fontSize: 14),
                children: [
                  TextSpan(
                    text: 'Sign In',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: 60),

        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mark_email_read_rounded,
              color: AppColors.success, size: 48),
        ),

        const SizedBox(height: 28),

        Text(
          'Check Your Email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'We\'ve sent a password reset link to\n${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: AppColors.textLight, height: 1.6),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Check your spam folder if you don\'t see the email in your inbox.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMid),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        PrimaryButton(
          label: 'Enter Reset Code',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ResetPasswordPage(email: _emailCtrl.text.trim()),
            ),
          ),
          icon: Icons.vpn_key_rounded,
        ),

        const SizedBox(height: 12),

        TextButton(
          onPressed: () {
            setState(() {
              _sent = false;
              _error = null;
            });
          },
          child: Text('Didn\'t receive email? Try again',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),

        const SizedBox(height: 16),

        TextButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
            }
          },
          child: Text('Back to Sign In',
              style: TextStyle(
                  color: AppColors.textMid,
                  fontSize: 13)),
        ),
      ],
    );
  }
}
