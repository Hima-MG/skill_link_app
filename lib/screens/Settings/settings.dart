// lib/screens/profile/settings_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/screens/Auth/login_screen.dart';

class SettingsPage extends StatefulWidget {
  final String userId;
  const SettingsPage({required this.userId, super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = false;
  bool _notifications = true;
  bool _darkMode = false;
  bool _saving = false;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;

  // static app version - replace with package_info_plus if desired
  static const String appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots();
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final doc = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);

      await doc.set({
        'settings': {
          'notifications': _notifications,
          'darkMode': _darkMode,
          'savedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (e) {
      debugPrint('Save settings error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save settings')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (should == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text(
          'This will remove your user document from Firestore. It will NOT delete your Firebase Auth account automatically. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (should == true) {
      try {
        setState(() => _loading = true);
        // remove Firestore user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .delete();
        // Optionally sign out the user as well
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        debugPrint('Delete account error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete account')),
        );
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _showAboutDialog() async {
    showAboutDialog(
      context: context,
      applicationName: 'SkillLink',
      applicationVersion: appVersion,
      applicationIcon: const SizedBox(
        width: 48,
        height: 48,
        child: Icon(Icons.school, color: AppColors.teal, size: 48),
      ),
      children: const [
        SizedBox(height: 8),
        Text('SkillLink helps learners and teachers connect and share skills.'),
      ],
    );
  }

  Future<void> _showPrivacyPolicy() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Privacy Policy'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Privacy Policy ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'We collect profile and post data to provide the service. We do not share personal information with third parties except to provide the service or if required by law.',
                ),
                SizedBox(height: 8),
                Text(
                  'For the full privacy policy, please visit your app store listing or the website.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePasswordFlow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }

    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Change password'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'New password (min 6 chars)',
              ),
              validator: (v) {
                if (v == null || v.trim().length < 6)
                  return 'Enter at least 6 characters';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false)
                  Navigator.pop(ctx, true);
              },
              child: const Text('Change'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final newPassword = ctrl.text.trim();
    try {
      // Attempt to update password directly
      await currentUser.updatePassword(newPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated')));
    } on FirebaseAuthException catch (e) {
      debugPrint('updatePassword error: $e');
      // If requires recent login, offer to send password reset email
      if (e.code == 'requires-recent-login' ||
          e.code == 'weak-password' ||
          e.code == 'operation-not-allowed') {
        final doReset = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Could not change password'),
            content: const Text(
              'Changing password requires a recent login. Would you like to receive a password reset email instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send reset email'),
              ),
            ],
          ),
        );

        if (doReset == true) {
          try {
            await FirebaseAuth.instance.sendPasswordResetEmail(
              email: currentUser.email ?? '',
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password reset email sent')),
            );
          } catch (e2) {
            debugPrint('sendPasswordResetEmail failed: $e2');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to send reset email')),
            );
          }
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password: ${e.message ?? e.code}'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Unknown changePassword error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to change password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        bool notif = _notifications;
        bool dark = _darkMode;
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() ?? {};
          final settings = data['settings'] as Map<String, dynamic>? ?? {};
          notif = (settings['notifications'] ?? notif) as bool;
          dark = (settings['darkMode'] ?? dark) as bool;
        }

        // initialize local state from snapshot only once (so toggles don't keep resetting)
        if (!_saving && !_loading && mounted) {
          _notifications = notif;
          _darkMode = dark;
        }

        // Use SingleChildScrollView to avoid bottom overflow when keyboard or small screens appear
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Settings',
              style: TextStyle(color: Colors.black87),
            ),
            backgroundColor: Colors.white,
            elevation: 0.5,
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
          backgroundColor: const Color(0xFFF5F5F9),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account',
                    style: AppTextStyles.title.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notifications'),
                    subtitle: const Text('Receive app notifications'),
                    trailing: Switch(
                      value: _notifications,
                      onChanged: (v) => setState(() => _notifications = v),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dark mode'),
                    subtitle: const Text(
                      'Use app dark theme (requires app-level handling)',
                    ),
                    trailing: Switch(
                      value: _darkMode,
                      onChanged: (v) => setState(() => _darkMode = v),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'App',
                    style: AppTextStyles.title.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Version'),
                    subtitle: Text(appVersion),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('About the app'),
                    onTap: _showAboutDialog,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Privacy Policy'),
                    onTap: _showPrivacyPolicy,
                  ),
                  const SizedBox(height: 16),

                  // Save + actions
                  if (_saving) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                          ),
                          child: Text(
                            _saving ? 'Saving...' : 'Save settings',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.teal,
                          ),
                          label: const Text(
                            'Change password',
                            style: TextStyle(color: AppColors.teal),
                          ),
                          onPressed: _changePasswordFlow,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.teal),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                          onPressed: _logout,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Delete account',
                            style: TextStyle(color: Colors.red),
                          ),
                          onPressed: _confirmDeleteAccount,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
