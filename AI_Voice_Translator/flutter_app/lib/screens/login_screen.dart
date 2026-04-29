import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _auth = AuthService();

  // ── State ──────────────────────────────────────────────────────────
  bool _isSignUp = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  // Animations
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween(begin: 0.0, end: 1.0).animate(_shakeCtrl);
    _slideCtrl.forward();
    
    _emailFocus.addListener(() => setState(() {}));
    _passFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _shakeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    
    if (email.isEmpty || !email.contains('@')) {
      _setError('Please enter a valid email address');
      _shakeCtrl.forward(from: 0);
      return;
    }
    if (pass.length < 6) {
      _setError('Password must be at least 6 characters');
      _shakeCtrl.forward(from: 0);
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      if (_isSignUp) {
        await _auth.signUpWithEmail(email, pass);
      } else {
        await _auth.signInWithEmail(email, pass);
      }
      // Auth state listener in main.dart will switch to main app automatically
    } catch (e) {
      _setError(_friendlyError(e.toString()));
      _shakeCtrl.forward(from: 0);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setError(String msg) => setState(() => _error = msg);

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found')) return 'No account found with this email';
    if (raw.contains('wrong-password') || raw.contains('invalid-credential')) return 'Incorrect email or password';
    if (raw.contains('email-already-in-use')) return 'An account already exists for that email';
    if (raw.contains('invalid-email')) return 'Invalid email address format';
    if (raw.contains('weak-password')) return 'Password is too weak. Use at least 6 characters';
    return raw; // Show actual Firebase error to debug if unknown
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _error = null;
    });
    _slideCtrl.reset();
    _slideCtrl.forward();
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBgGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) {
                  final shake = (_shakeAnim.value * 12 * 4).round() % 2 == 0
                      ? (_shakeAnim.value * 8).toDouble()
                      : -(_shakeAnim.value * 8).toDouble();
                  return Transform.translate(offset: Offset(shake, 0), child: child);
                },
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 48),
                      _buildForm(),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _buildError(),
                      ],
                      const SizedBox(height: 28),
                      _buildPrimaryButton(
                        onTap: _loading ? null : _submit,
                        label: _isSignUp ? 'Create Account' : 'Sign In',
                        icon: _isSignUp ? Icons.person_add_rounded : Icons.login_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildFooterToggle(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: kPrimaryGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.translate_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 24),
        Text('AI Voice Translator',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: kTextPrimary)),
        const SizedBox(height: 8),
        Text(
          _isSignUp ? 'Sign up for a free account' : 'Sign in to your account',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 15, color: kTextSecondary, height: 1.5),
        ),
      ],
    );
  }

  // ── Form Step ─────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email Field
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _emailFocus.hasFocus ? kPrimaryLight.withOpacity(0.5) : kGlassBorder),
          ),
          child: TextField(
            controller: _emailCtrl,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: GoogleFonts.inter(color: kTextPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Email address',
              hintStyle: GoogleFonts.inter(color: kTextHint, fontSize: 16),
              prefixIcon: const Icon(Icons.email_outlined, color: kTextHint, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Password Field
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _passFocus.hasFocus ? kPrimaryLight.withOpacity(0.5) : kGlassBorder),
          ),
          child: TextField(
            controller: _passCtrl,
            focusNode: _passFocus,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: GoogleFonts.inter(color: kTextPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: GoogleFonts.inter(color: kTextHint, fontSize: 16),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: kTextHint, size: 20),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: kTextHint, size: 20,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({VoidCallback? onTap, required String label, required IconData icon}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: enabled ? kPrimaryGradient : null,
          color: enabled ? null : kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: enabled ? Colors.transparent : kGlassBorder),
          boxShadow: enabled ? [BoxShadow(color: kPrimary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_loading)
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            else
              Icon(icon, color: enabled ? Colors.white : kTextHint, size: 20),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: enabled ? Colors.white : kTextHint)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kError.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kError.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: kError, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!, style: GoogleFonts.inter(color: kError, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildFooterToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUp ? 'Already have an account?' : 'Don\'t have an account?',
          style: GoogleFonts.inter(color: kTextSecondary, fontSize: 13),
        ),
        TextButton(
          onPressed: _loading ? null : _toggleMode,
          child: Text(
            _isSignUp ? 'Sign In' : 'Sign Up',
            style: GoogleFonts.inter(color: kPrimaryLight, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
