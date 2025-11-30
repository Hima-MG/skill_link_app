import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/core/app_validators.dart';
import 'package:skill_link_app/core/app_widget.dart';

class RegisterScreen extends StatefulWidget {
  final GlobalKey<FormState>? formKey;
  const RegisterScreen({super.key, this.formKey});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final GlobalKey<FormState> _formKey;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  int _selectedIntent = 2; // 0=Learn,1=Teach,2=Both

  @override
  void initState() {
    super.initState();
    _formKey = widget.formKey ?? GlobalKey<FormState>();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  String _intentLabel(int idx) => ['Learn', 'Teach', 'Both'][idx];

  Future<void> _createAccount() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pass = _passwordCtrl.text;

    try {
      setState(() => _isLoading = true);

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'Unable to create user',
        );
      }

      await user.updateDisplayName(name);
      await user.reload();

      final usersRef = FirebaseFirestore.instance.collection('users');
      await usersRef.doc(user.uid).set({
        'displayName': name,
        'email': email,
        'phone': phone,
        'intent': _intentLabel(_selectedIntent),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      try {
        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }
      } catch (_) {
        // ignore email verification errors
      }

      if (!mounted) return;
      _showSnack('Account created for $name');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Registration failed';
      if (e.code == 'email-already-in-use') {
        msg = 'That email is already in use.';
      }
      if (e.code == 'weak-password') {
        msg = 'The given password is too weak.';
      }
      if (e.code == 'invalid-email') {
        msg = 'The email address is invalid.';
      }
      _showSnack(msg);
    } catch (_) {
      _showSnack('Registration failed. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _intentButton({required Widget child, required int idx}) {
    final selected = _selectedIntent == idx;
    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
              setState(() => _selectedIntent = idx);
            },
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: AppColors.teal, width: 2)
              : Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            child,
            const SizedBox(height: 6),
            Text(
              ['Learn', 'Teach', 'Both'][idx],
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, outer) {
            final horizontalPadding = outer.maxWidth < 420 ? 10.0 : 18.0;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: outer.maxHeight),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 18,
                    ),
                    child: LayoutBuilder(
                      builder: (context, inner) {
                        final maxCardWidth = min(520.0, inner.maxWidth);
                        return SizedBox(
                          width: maxCardWidth,
                          child: Card(
                            elevation: 1.2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Create Account',
                                      style: AppTextStyles.heading.copyWith(
                                        fontSize: 20,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Join SkillLink today',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Name
                                    AppWidgets.inputField(
                                      controller: _nameCtrl,
                                      hint: 'Full Name',
                                      icon: Icons.person_outline,
                                      validator: (value) {
                                        final v = value?.trim() ?? '';
                                        if (v.isEmpty) {
                                          return 'Full name is required';
                                        }
                                        if (v.length < 3) {
                                          return 'Enter a valid name';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),

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
                                    const SizedBox(height: 20),

                                    // Phone
                                    AppWidgets.inputField(
                                      controller: _phoneCtrl,
                                      hint: 'Phone Number',
                                      icon: Icons.phone_outlined,
                                      type: TextInputType.phone,
                                      validator: (value) {
                                        final v = value?.trim() ?? '';
                                        if (v.isEmpty) {
                                          return 'Phone number is required';
                                        }
                                        if (v.length < 6) {
                                          return 'Enter a valid phone number';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    // Password
                                    AppWidgets.inputField(
                                      controller: _passwordCtrl,
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

                                    const SizedBox(height: 10),
                                    const Text(
                                      'I want to:',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _intentButton(
                                          idx: 0,
                                          child: const Icon(
                                            Icons.menu_book,
                                            color: Colors.green,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        _intentButton(
                                          idx: 1,
                                          child: const Icon(
                                            Icons.school,
                                            color: Colors.deepPurple,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        _intentButton(
                                          idx: 2,
                                          child: const Icon(
                                            Icons.handshake,
                                            color: Colors.orange,
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 25),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _createAccount,
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
                                                'Create Account',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
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
