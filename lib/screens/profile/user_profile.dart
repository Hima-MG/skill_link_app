import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/core/app_widget.dart';
import 'package:skill_link_app/screens/Auth/login_screen.dart';
import 'package:skill_link_app/screens/chat/chat_screen.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  bool _avatarUploading = false;
  bool _savingProfile = false;

  // ---- controllers for edit profile dialog (best practice) ----
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _headlineCtrl = TextEditingController();
  final TextEditingController _aboutCtrl = TextEditingController();
  final TextEditingController _skillsCtrl = TextEditingController();
  final TextEditingController _certificateCtrl = TextEditingController();

  static const String _cloudName = 'duando6bf';
  static const String _uploadPreset = 'SkillLink';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _headlineCtrl.dispose();
    _aboutCtrl.dispose();
    _skillsCtrl.dispose();
    _certificateCtrl.dispose();
    super.dispose();
  }

  Future<String?> _uploadToCloudinary(File file) async {
    try {
      final cloudinary = CloudinaryPublic(
        _cloudName,
        _uploadPreset,
        cache: false,
      );

      final res = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'skilllink_avatars',
        ),
      );

      return res.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary avatar upload error: $e');
      return null;
    }
  }

  Future<void> _changeAvatar(String profileUid) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _avatarUploading = true);

    try {
      final file = File(picked.path);
      final url = await _uploadToCloudinary(file);

      if (url == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to upload image')));
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(profileUid).set({
        'avatarUrl': url,
      }, SetOptions(merge: true));

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid == profileUid) {
        await user.updatePhotoURL(url);
      }
    } catch (e) {
      debugPrint('Change avatar error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile picture')),
      );
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  /// Edit profile dialog
  Future<Map<String, dynamic>?> _showEditProfileDialog({
    required String currentName,
    required String currentHeadline,
    required String currentAbout,
    required List<String> currentSkills,
    required List<String> currentCertificates,
  }) async {
    // set current values into controllers
    _nameCtrl.text = currentName;
    _headlineCtrl.text = currentHeadline;
    _aboutCtrl.text = currentAbout;
    _skillsCtrl.text = currentSkills.join(', ');
    _certificateCtrl.text = currentCertificates.join(', ');

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Edit Profile', style: AppTextStyles.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppWidgets.inputField(
                  controller: _nameCtrl,
                  hint: 'Name (optional)',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                AppWidgets.inputField(
                  controller: _headlineCtrl,
                  hint: 'Headline (optional)',
                  icon: Icons.work_outline,
                ),
                const SizedBox(height: 10),
                AppWidgets.inputField(
                  controller: _aboutCtrl,
                  hint: 'About (optional)',
                  icon: Icons.info_outline,
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                AppWidgets.inputField(
                  controller: _skillsCtrl,
                  hint: 'Skills (comma separated, optional)',
                  icon: Icons.star_outline,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                AppWidgets.inputField(
                  controller: _certificateCtrl,
                  hint: 'Certifications (comma separated, optional)',
                  icon: Icons.edit_attributes_sharp,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final name = _nameCtrl.text.trim();
                final headline = _headlineCtrl.text.trim();
                final about = _aboutCtrl.text.trim();
                final skills = _skillsCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                final certificates = _certificateCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                Navigator.of(ctx).pop(<String, dynamic>{
                  'name': name,
                  'headline': headline,
                  'about': about,
                  'skills': skills,
                  'certificates': certificates,
                });
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    // no manual dispose here – controllers belong to State

    return result;
  }

  Future<void> _editProfile({
    required String profileUid,
    required String currentName,
    required String currentHeadline,
    required String currentAbout,
    required List<String> currentSkills,
    required List<String> currentCertificates,
  }) async {
    final result = await _showEditProfileDialog(
      currentName: currentName,
      currentHeadline: currentHeadline,
      currentAbout: currentAbout,
      currentSkills: currentSkills,
      currentCertificates: currentCertificates,
    );

    if (!mounted || result == null) return;

    setState(() => _savingProfile = true);

    try {
      final rawName = (result['name'] as String?) ?? '';
      final rawHeadline = (result['headline'] as String?) ?? '';
      final rawAbout = (result['about'] as String?) ?? '';
      final rawSkills = result['skills'] as List? ?? <String>[];
      final rawCertificates = result['certificates'] as List? ?? <String>[];

      final newName = rawName.trim().isEmpty ? currentName : rawName.trim();
      final newHeadline = rawHeadline.trim();
      final newAbout = rawAbout.trim();
      final newSkills = List<String>.from(rawSkills);
      final newCertificates = List<String>.from(rawCertificates);

      final usersRef = FirebaseFirestore.instance
          .collection('users')
          .doc(profileUid);

      await usersRef.set({
        'displayName': newName,
        'name': newName,
        'headline': newHeadline,
        'about': newAbout,
        'skills': newSkills,
        'certificates': newCertificates,
      }, SetOptions(merge: true));

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid == profileUid) {
        await user.updateDisplayName(newName);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      debugPrint('Edit profile error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update profile')));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  void _showMessageOptions({required String name, required String toUserId}) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Message $name',
                style: AppTextStyles.title.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Open chat'),
                subtitle: const Text('Start conversation in SkillLink'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatScreen(peerId: toUserId, peerName: name),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Logout",
          style: AppTextStyles.title.copyWith(color: Colors.red),
        ),
        content: Text(
          "Are you sure you want to logout?",
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Cancel",
              style: AppTextStyles.body.copyWith(color: AppColors.textDark),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              "Logout",
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final profileUid = widget.userId ?? currentUser?.uid;

    if (profileUid == null) {
      return const Scaffold(body: Center(child: Text('No user logged in')));
    }

    final bool isOwner = currentUser != null && currentUser.uid == profileUid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: Text(
          isOwner ? 'My Profile' : 'Profile',
          style: AppTextStyles.title.copyWith(
            fontSize: 20,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          if (_savingProfile)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: _logout,
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(profileUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load profile\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Profile not found.\nCreate a user document in Firestore.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            );
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>? ??
              <String, dynamic>{};

          final currentName =
              (data['displayName'] ??
                      data['name'] ??
                      currentUser?.displayName ??
                      'Your Name')
                  as String;

          final currentHeadline = (data['headline'] ?? '') as String;
          final avatarUrl = (data['avatarUrl'] ?? '') as String;
          final currentAbout = (data['about'] ?? '') as String;
          final currentSkills = List<String>.from(data['skills'] ?? <String>[]);
          final currentCertificates = List<String>.from(
            data['certificates'] ?? <String>[],
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Avatar
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                backgroundColor: AppColors.fieldBg,
                                child: avatarUrl.isEmpty
                                    ? Text(
                                        currentName.isNotEmpty
                                            ? currentName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : null,
                              ),
                              if (isOwner)
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: GestureDetector(
                                    onTap: _avatarUploading
                                        ? null
                                        : () => _changeAvatar(profileUid),
                                    child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: AppColors.teal,
                                      child: _avatarUploading
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.edit,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentName,
                                  style: AppTextStyles.heading.copyWith(
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (currentHeadline.isNotEmpty)
                                  Text(
                                    currentHeadline,
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          if (isOwner)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _savingProfile
                                    ? null
                                    : () => _editProfile(
                                        profileUid: profileUid,
                                        currentName: currentName,
                                        currentHeadline: currentHeadline,
                                        currentAbout: currentAbout,
                                        currentSkills: currentSkills,
                                        currentCertificates:
                                            currentCertificates,
                                      ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit profile'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showMessageOptions(
                                  name: currentName,
                                  toUserId: profileUid,
                                ),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Message'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _SectionCard(
                title: 'About',
                child: Text(
                  currentAbout.isEmpty
                      ? (isOwner
                            ? 'Write something about yourself so learners & teachers can know you better.'
                            : 'No about info yet.')
                      : currentAbout,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _SectionCard(
                title: 'Skills',
                child: currentSkills.isEmpty
                    ? Text(
                        isOwner
                            ? 'Add your skills from the edit profile option.'
                            : 'No skills added yet.',
                        style: AppTextStyles.caption,
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: currentSkills
                            .map(
                              (s) => Chip(
                                label: Text(
                                  s,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.teal,
                                  ),
                                ),
                                backgroundColor: const Color(0xFFF1F7F7),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),

              const SizedBox(height: 16),

              _SectionCard(
                title: 'Certifications',
                child: currentCertificates.isEmpty
                    ? Text(
                        isOwner
                            ? 'Add your certificates from the edit profile option.'
                            : 'No certifications added yet.',
                        style: AppTextStyles.caption,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: currentCertificates
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.verified_outlined,
                                      size: 18,
                                      color: AppColors.teal,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        s,
                                        style: AppTextStyles.body.copyWith(
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),

              const SizedBox(height: 16),

              _UserPostsSection(userId: profileUid, isOwner: isOwner),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _UserPostsSection extends StatelessWidget {
  final String userId;
  final bool isOwner;

  const _UserPostsSection({required this.userId, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final postsQuery = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: postsQuery.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'No posts found',
                style: AppTextStyles.caption.copyWith(color: Colors.red),
              ),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];

        return _SectionCard(
          title: isOwner ? 'My Posts' : 'Posts',
          child: docs.isEmpty
              ? Text(
                  isOwner
                      ? 'You haven\'t shared any posts yet.'
                      : 'No posts yet.',
                  style: AppTextStyles.caption,
                )
              : Column(
                  children: docs
                      .map((d) => _buildPostCard(context, d.data()))
                      .toList(),
                ),
        );
      },
    );
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> data) {
    final content =
        (data['content'] ?? data['text'] ?? data['caption'] ?? '') as String;
    final imageUrl = (data['imageUrl'] ?? '') as String;
    final timestamp = data['createdAt'];
    DateTime? created;
    if (timestamp is Timestamp) created = timestamp.toDate();

    String timeText = '';
    if (created != null) {
      timeText =
          '${created.day}/${created.month}/${created.year} • ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (timeText.isNotEmpty)
            Text(timeText, style: AppTextStyles.caption.copyWith(fontSize: 11)),
          if (timeText.isNotEmpty) const SizedBox(height: 4),
          if (content.isNotEmpty)
            Text(content, style: AppTextStyles.body.copyWith(fontSize: 14)),
          if (content.isNotEmpty && imageUrl.isNotEmpty)
            const SizedBox(height: 8),
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.title.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
