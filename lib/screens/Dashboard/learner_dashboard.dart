// lib/screens/Dashboard/learner_dashboard.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/screens/Explore/course_ui.dart';
import 'package:skill_link_app/screens/profile/user_profile.dart';

class LearnerDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;
  const LearnerDashboard({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final uid = user.uid;
    final name =
        userData['displayName'] ??
        userData['name'] ??
        user.displayName ??
        'Learner';
    final headline = userData['headline'] ?? 'Learning new skills on SkillLink';
    final avatarUrl = userData['avatarUrl'] ?? '';
    final email = userData['email'] ?? user.email ?? '';

    final enrolledQuery = FirebaseFirestore.instance
        .collection('courses')
        .where('enrolledUsers', arrayContains: uid);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hi,', style: TextStyle(fontSize: 11)),
            Text(name, style: AppTextStyles.heading.copyWith(fontSize: 18)),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: enrolledQuery.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];

          // simple stats
          int total = docs.length;
          int completed = 0;
          for (final d in docs) {
            final data = d.data();
            final completedUsers =
                (data['completedUsers'] as List<dynamic>? ?? []);
            if (completedUsers.contains(uid)) completed++;
          }
          final inProgress = total - completed;

          if (docs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const SizedBox(height: 8),
                _DashboardProfileHeader(
                  name: name,
                  roleLabel: 'Learner',
                  headline: headline,
                  avatarUrl: avatarUrl,
                  email: email,
                  onViewProfile: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(userId: uid),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Total',
                        value: '$total',
                        icon: Icons.menu_book_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'In Progress',
                        value: '$inProgress',
                        icon: Icons.play_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Completed',
                        value: '$completed',
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 30,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        size: 40,
                        color: Colors.black26,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'You are not enrolled in any course yet.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Explore courses and start learning!',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const SizedBox(height: 8),

              // mini profile at top
              _DashboardProfileHeader(
                name: name,
                roleLabel: 'Learner',
                headline: headline,
                avatarUrl: avatarUrl,
                email: email,
                onViewProfile: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfilePage(userId: uid)),
                  );
                },
              ),

              const SizedBox(height: 16),

              // stats row
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total',
                      value: '$total',
                      icon: Icons.menu_book_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'In Progress',
                      value: '$inProgress',
                      icon: Icons.play_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Completed',
                      value: '$completed',
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Continue Learning',
                    style: AppTextStyles.title.copyWith(fontSize: 16),
                  ),
                  Text('${docs.length} courses', style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(height: 10),

              ...docs.map((doc) {
                final data = doc.data();
                final title = data['title'] as String? ?? 'Untitled course';
                final desc = data['description'] as String? ?? '';
                final imageUrl = data['imageUrl'] as String? ?? '';
                final teacherName = data['teacherName'] as String? ?? 'Teacher';
                final progress = 0.3; // TODO: hook to real progress later

                return _LearnerCourseCard(
                  title: title,
                  description: desc,
                  teacherName: teacherName,
                  imageUrl: imageUrl,
                  progress: progress,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseDetailScreen(
                          courseId: doc.id,
                          data: data,
                          currentUserId: uid,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}

/* ---------------------------- helper widgets ---------------------------- */

class _DashboardProfileHeader extends StatelessWidget {
  final String name;
  final String roleLabel;
  final String headline;
  final String avatarUrl;
  final String email;
  final VoidCallback onViewProfile;

  const _DashboardProfileHeader({
    required this.name,
    required this.roleLabel,
    required this.headline,
    required this.avatarUrl,
    required this.email,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  backgroundColor: AppColors.fieldBg,
                  child: avatarUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.heading.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roleLabel,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (headline.isNotEmpty)
                        Text(
                          headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    email,
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: onViewProfile,
                  child: const Text('View profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: AppColors.teal),
          ),
          const SizedBox(width: 8),
          Expanded(
            // <-- this avoids overflow
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnerCourseCard extends StatelessWidget {
  final String title;
  final String description;
  final String teacherName;
  final String imageUrl;
  final double progress;
  final VoidCallback onTap;

  const _LearnerCourseCard({
    required this.title,
    required this.description,
    required this.teacherName,
    required this.imageUrl,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                  child: imageUrl.isEmpty
                      ? Container(
                          width: 90,
                          height: 90,
                          color: AppColors.fieldBg,
                          child: const Icon(Icons.image_outlined),
                        )
                      : Image.network(
                          imageUrl,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 10,
                      right: 10,
                      bottom: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'By $teacherName',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.fieldBg,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${(progress * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Continue learning',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
