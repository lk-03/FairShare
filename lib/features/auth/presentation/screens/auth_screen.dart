import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../data/providers/auth_provider.dart';

enum AuthMode {
  options,
  emailSignIn,
  emailSignUp,
  emailVerify,
}

class AuthSuccessData {
  final String provider;
  final String email;
  final String fullName;
  final bool isNewUser;
  final UserProfile? userProfile;

  const AuthSuccessData({
    required this.provider,
    required this.email,
    required this.fullName,
    this.isNewUser = false,
    this.userProfile,
  });
}

/// AuthScreen handles multiple authentication modes: Google Sign-In, Email/Password
/// authentication, email verification countdown, and zero-friction Guest mode.
class AuthScreen extends ConsumerStatefulWidget {
  final AuthMode initialMode;
  final ValueChanged<AuthSuccessData>? onAuthenticated;
  final VoidCallback? onBack;

  const AuthScreen({
    super.key,
    this.initialMode = AuthMode.options,
    this.onAuthenticated,
    this.onBack,
  });

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late AuthMode _mode;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  int _resendCooldown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _showMessage(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.colors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.colors.border, width: 1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.colors.cyan,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message,
              style: TextStyle(
                color: context.colors.textMain,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final profile = await authRepo.signInWithNativeGoogle();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (profile != null) {
        widget.onAuthenticated?.call(
          AuthSuccessData(
            provider: 'google',
            email: profile.email ?? 'user@gmail.com',
            fullName: profile.fullName,
            isNewUser: false,
            userProfile: profile,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        'Google Sign-In Notice',
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> _handleGuestAuth() async {
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final profile = await authRepo.signInAsGuest();
      if (!mounted) return;
      setState(() => _isLoading = false);

      widget.onAuthenticated?.call(
        AuthSuccessData(
          provider: 'guest',
          email: profile.email ?? 'guest@fairshare.app',
          fullName: profile.fullName,
          isNewUser: true,
          userProfile: profile,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Guest Entry Notice', e.toString());
    }
  }

  Future<void> _handleEmailSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Invalid Email', 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      _showMessage(
        'Password Required',
        'Password must be at least 6 characters.',
      );
      return;
    }
    if (_mode == AuthMode.emailSignUp && name.isEmpty) {
      _showMessage('Name Required', 'Please enter your name.');
      return;
    }

    setState(() => _isLoading = true);
    final authRepo = ref.read(authRepositoryProvider);

    try {
      if (_mode == AuthMode.emailSignUp) {
        final res = await authRepo.signUpWithEmail(
          email,
          password,
          name,
        );
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (res.requiresEmailConfirmation) {
          setState(() => _mode = AuthMode.emailVerify);
          _showMessage(
            'Confirmation Email Sent',
            'We have sent a verification link to $email. Please check your inbox!',
          );
        } else if (res.user != null) {
          widget.onAuthenticated?.call(
            AuthSuccessData(
              provider: 'email',
              email: email,
              fullName: name,
              isNewUser: true,
              userProfile: res.user,
            ),
          );
        }
      } else {
        final profile = await authRepo.signInWithEmail(
          email,
          password,
        );
        if (!mounted) return;
        setState(() => _isLoading = false);

        widget.onAuthenticated?.call(
          AuthSuccessData(
            provider: 'email',
            email: profile.email ?? email,
            fullName: profile.fullName.isNotEmpty
                ? profile.fullName
                : email.split('@')[0],
            isNewUser: false,
            userProfile: profile,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        _mode == AuthMode.emailSignUp ? 'Sign Up Failed' : 'Sign In Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> _handleResendVerification() async {
    if (_resendCooldown > 0) return;
    final email = _emailController.text.trim();
    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.resendConfirmationEmail(email);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _resendCooldown = 30;
      });
      _showMessage('Email Resent', 'A new verification email has been sent to $email');

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_resendCooldown <= 1) {
            _resendCooldown = 0;
            timer.cancel();
          } else {
            _resendCooldown--;
          }
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Resend Failed', e.toString());
    }
  }

  Future<void> _handleCheckVerification() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final profile = await authRepo.signInWithEmail(
        email,
        password,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      widget.onAuthenticated?.call(
        AuthSuccessData(
          provider: 'email',
          email: profile.email ?? email,
          fullName: profile.fullName.isNotEmpty
              ? profile.fullName
              : email.split('@')[0],
          isNewUser: false,
          userProfile: profile,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        'Not Verified Yet',
        'Please click the link in your email to verify before continuing.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.screen,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Navigation Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.onBack != null || _mode != AuthMode.options)
                      IconButton(
                        onPressed: () {
                          if (_mode != AuthMode.options) {
                            setState(() => _mode = AuthMode.options);
                          } else {
                            widget.onBack?.call();
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: colors.surface,
                          side: BorderSide(color: colors.border, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: colors.textMain,
                        ),
                      )
                    else
                      const SizedBox(width: 48),

                    Row(
                      children: [
                        const AppLogo(size: 26, withGlow: true, withShadow: true),
                        const SizedBox(width: 8),
                        Text(
                          'FairShare',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: colors.textMain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                // Main Form Content
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: _buildBody(colors),
                  ),
                ),

                // Legal Disclaimer Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "By continuing, you agree to FairShare's transparent ledger terms and privacy principles.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppThemeColors colors) {
    switch (_mode) {
      case AuthMode.emailVerify:
        return _buildEmailVerifyView(colors);
      case AuthMode.emailSignIn:
      case AuthMode.emailSignUp:
        return _buildEmailFormView(colors);
      case AuthMode.options:
        return _buildOptionsView(colors);
    }
  }

  // ---------------------------------------------------------------------------
  // AUTH OPTIONS VIEW (Google, Email, Guest, Sign Up Switch)
  // ---------------------------------------------------------------------------
  Widget _buildOptionsView(AppThemeColors colors) {
    return Column(
      children: [
        // Title banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colors.accentPill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Text(
            'CLOUD-SYNCED GROUP LEDGER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: colors.cyan,
            ),
          ),
        ),
        Text(
          'Welcome to FairShare',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: colors.textMain,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Split transparently with roommates, trips, and friends with real-time cloud sync',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        // 1: Native Google Sign-In Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _handleGoogleAuth,
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.border, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: colors.cyan,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google 'G' icon / colored dot
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        child: const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFEA4335),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // 2: Email Sign In Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => setState(() => _mode = AuthMode.emailSignIn),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accentPill,
              foregroundColor: colors.textMain,
              elevation: 0,
              side: BorderSide(color: colors.border, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline_rounded, size: 18, color: colors.cyan),
                const SizedBox(width: 10),
                Text(
                  'Continue with Email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.textMain,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3: Continue as Guest Button (Zero friction)
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _handleGuestAuth,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              side: BorderSide(
                color: colors.borderSubtle,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Continue as Guest',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4: Create Account Switcher
        TextButton(
          onPressed: () => setState(() => _mode = AuthMode.emailSignUp),
          child: Text(
            'New to FairShare? Create an Account',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.cyan,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // EMAIL FORM VIEW (Sign In & Sign Up)
  // ---------------------------------------------------------------------------
  Widget _buildEmailFormView(AppThemeColors colors) {
    final isSignUp = _mode == AuthMode.emailSignUp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                isSignUp ? 'Create FairShare Account' : 'Sign in with Email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: colors.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your credentials to access your cloud-synced ledgers',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Full name field (Only for sign-up)
        if (isSignUp) ...[
          Text(
            'FULL NAME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textMain,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Alex Doe',
              hintStyle: TextStyle(
                color: colors.textMuted,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              filled: true,
              fillColor: colors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colors.cyan, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Email address field
        Text(
          'EMAIL ADDRESS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.textMain,
          ),
          decoration: InputDecoration(
            hintText: 'name@example.com',
            hintStyle: TextStyle(
              color: colors.textMuted,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            filled: true,
            fillColor: colors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.cyan, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Password field
        Text(
          'PASSWORD',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          autocorrect: false,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.textMain,
          ),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(
              color: colors.textMuted,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            filled: true,
            fillColor: colors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: colors.textSecondary,
              ),
              onPressed: () =>
                  setState(() => _showPassword = !_showPassword),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.cyan, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleEmailSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.cyan,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF0F172A),
                    ),
                  )
                : Text(
                    isSignUp ? 'Create Account' : 'Sign In',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),

        // Toggle Sign In / Sign Up
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _mode =
                  isSignUp ? AuthMode.emailSignIn : AuthMode.emailSignUp;
            }),
            child: Text(
              isSignUp
                  ? 'Already have an account? Sign In'
                  : "Don't have an account? Sign Up",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: colors.cyan,
              ),
            ),
          ),
        ),

        // Return to options
        Center(
          child: TextButton(
            onPressed: () => setState(() => _mode = AuthMode.options),
            child: Text(
              'Back to all sign-in options',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // EMAIL VERIFY VIEW
  // ---------------------------------------------------------------------------
  Widget _buildEmailVerifyView(AppThemeColors colors) {
    final email = _emailController.text.trim();

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.cyan.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.cyan.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.mark_email_unread_outlined,
            size: 34,
            color: colors.cyan,
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Check Your Inbox',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: colors.textMain,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a confirmation link to:',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: colors.cyan,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Click the link in your email to activate your account.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),

        // I've Verified Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleCheckVerification,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.cyan,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF0F172A),
                    ),
                  )
                : const Text(
                    "I've Verified (Continue)",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // Resend Verification Email
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: (_isLoading || _resendCooldown > 0)
                ? null
                : _handleResendVerification,
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.border, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _resendCooldown > 0
                  ? 'Resend in ${_resendCooldown}s'
                  : 'Resend Verification Email',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _resendCooldown > 0
                    ? colors.textMuted
                    : colors.textMain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Back to Sign In
        TextButton(
          onPressed: () => setState(() => _mode = AuthMode.emailSignIn),
          child: Text(
            'Back to Sign In',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
