import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/core/app_validators.dart';
import 'package:skill_link_app/core/app_widget.dart';
import 'package:skill_link_app/screens/Home/home_screen.dart';

import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final GlobalKey<FormState>? formKey;
  const LoginScreen({super.key, this.formKey});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final GlobalKey<FormState> _formKey;

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _formKey = widget.formKey ?? GlobalKey<FormState>();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loginWithEmail() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    // validate using the Form + validators on fields
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    try {
      setState(() => _isLoading = true);
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Login failed';
      if (e.code == 'user-not-found') msg = 'No account found for that email.';
      if (e.code == 'wrong-password') msg = 'Incorrect password.';
      _showSnack(msg);
    } catch (_) {
      _showSnack('Login failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnack('Enter your email to reset password.');
      return;
    }
    if (!Validators.email.hasMatch(email)) {
      _showSnack('Enter a valid email.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack('Password reset email sent.');
    } catch (_) {
      _showSnack('Failed to send password reset email.');
    }
  }

  void _googleComingSoon() {
    if (_isLoading) return;
    _showSnack('This option is coming soon!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, outer) {
            final horizontalPadding = outer.maxWidth < 420 ? 10.0 : 24.0;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: outer.maxHeight),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 20,
                    ),
                    child: LayoutBuilder(
                      builder: (context, inner) {
                        final maxCardWidth = min(480.0, inner.maxWidth);
                        return SizedBox(
                          width: maxCardWidth,
                          child: Card(
                            color: AppColors.cardBg,
                            elevation: 1.2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'SkillLink',
                                      style: AppTextStyles.heading.copyWith(
                                        fontSize: 26,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Learn. Teach. Connect.',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 25),

                                    // Email
                                    AppWidgets.inputField(
                                      controller: _emailCtrl,
                                      hint: 'Email',
                                      icon: Icons.mail_outline,
                                      type: TextInputType.emailAddress,
                                      validator: (value) {
                                        final v = value?.trim() ?? '';
                                        if (v.isEmpty) {
                                          return 'Email is required';
                                        }
                                        if (!Validators.email.hasMatch(v)) {
                                          return 'Enter a valid email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 25),

                                    // Password
                                    AppWidgets.inputField(
                                      controller: _passCtrl,
                                      hint: 'Password',
                                      icon: Icons.lock_outline,
                                      obscure: _obscure,
                                      validator: (value) {
                                        final v = value ?? '';
                                        if (v.isEmpty) {
                                          return 'Password is required';
                                        }
                                        if (v.length < 6) {
                                          return 'Password must be at least 6 characters';
                                        }
                                        return null;
                                      },
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.black54,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscure = !_obscure;
                                          });
                                        },
                                      ),
                                    ),

                                    // Forgot password
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: _sendPasswordReset,
                                          child: const Text(
                                            'Forgot password?',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 15),

                                    // Login button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _loginWithEmail,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.teal,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Text(
                                                'Log In',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),

                                    const SizedBox(height: 2),

                                    // OR divider
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            color: Colors.grey.shade300,
                                            thickness: 1,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Text(
                                            'or',
                                            style: TextStyle(
                                              color: Colors.black45,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color: Colors.grey.shade300,
                                            thickness: 1,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Google button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: OutlinedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _googleComingSoon,
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          side: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: Image.asset(
                                                'assets/download.png',
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Text(
                                              'Continue with Google',
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // Register link
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            text: "Don't have an account? ",
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 13,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: 'Register',
                                                style: TextStyle(
                                                  color: AppColors.teal,
                                                  fontSize: 13,
                                                  decoration:
                                                      TextDecoration.underline,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                recognizer: TapGestureRecognizer()
                                                  ..onTap = () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const RegisterScreen(),
                                                      ),
                                                    );
                                                  },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
