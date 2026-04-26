import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

// ════════════════════════════════════════════════════════════
//  RESET PASSWORD PAGE
// ════════════════════════════════════════════════════════════
class ResetPasswordPage extends StatefulWidget {
  final String email;
  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _success = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _authService.resetPassword(
      widget.email,
      _tokenCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success']) {
      setState(() => _success = true);
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _success ? _buildSuccessState() : _buildFormState(),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.vpn_key_rounded,
                color: AppColors.accent, size: 36),
          ),
        ),

        const SizedBox(height: 24),

        Center(
          child: Text(
            'Reset Password',
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
            'Enter the code sent to\n${widget.email}',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: AppColors.textLight, height: 1.5),
          ),
        ),

        const SizedBox(height: 32),

        Form(
          key: _formKey,
          child: Column(
            children: [
              // Reset Token
              TextFormField(
                controller: _tokenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reset code',
                  prefixIcon: Icon(Icons.pin_rounded, size: 20),
                  hintText: 'Paste the code from your email',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter the reset code';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // New Password
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a new password';
                  if (v.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Confirm Password
              TextFormField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: Icon(Icons.lock_outline, size: 20),
                ),
                validator: (v) {
                  if (v != _passwordCtrl.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(message: _error!),
              ],

              const SizedBox(height: 24),

              PrimaryButton(
                label: 'Reset Password',
                onTap: _resetPassword,
                loading: _loading,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: 80),

        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 52),
        ),

        const SizedBox(height: 28),

        Text(
          'Password Reset!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Your password has been successfully reset.\nYou can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: AppColors.textLight, height: 1.6),
        ),

        const SizedBox(height: 32),

        PrimaryButton(
          label: 'Back to Sign In',
          onTap: () {
            // Pop all the way back to login
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          icon: Icons.login_rounded,
        ),
      ],
    );
  }
}
