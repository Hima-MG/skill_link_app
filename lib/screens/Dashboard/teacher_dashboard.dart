// lib/screens/Dashboard/teacher_dashboard.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/screens/Explore/course_ui.dart';

import 'package:skill_link_app/screens/Explore/create_corse.dart';
import 'package:skill_link_app/screens/profile/user_profile.dart';

class TeacherDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;

  const TeacherDashboard({super.key, required this.userData});

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
        'Teacher';
    final headline = userData['headline'] ?? 'Sharing skills on SkillLink';
    final avatarUrl = userData['avatarUrl'] ?? '';
    final email = userData['email'] ?? user.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Dashboard',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage your courses, $name',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const SizedBox(height: 12),

            // mini profile header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _DashboardProfileHeader(
                name: name,
                roleLabel: 'Instructor',
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
            ),

            const SizedBox(height: 12),
            _TopInfoStrip(userId: uid),
            const SizedBox(height: 20),

            // pill style tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black54,
                  indicator: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.all(Radius.circular(26)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(text: 'My Courses'),
                    Tab(text: 'Students'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _TeacherCoursesSection(userId: uid),
                  _TeacherLearnersSection(userId: uid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------- profile header card -------------------------- */

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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
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
            const SizedBox(height: 8),
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

/* ------------------------------- stats strip ------------------------------ */

class _TopInfoStrip extends StatelessWidget {
  final String userId;
  const _TopInfoStrip({required this.userId});

  @override
  Widget build(BuildContext context) {
    final coursesQuery = FirebaseFirestore.instance
        .collection('courses')
        .where('teacherId', isEqualTo: userId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: coursesQuery.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        int courseCount = docs.length;
        int learnerCount = 0;
        double earnings = 0;

        for (var d in docs) {
          final data = d.data();
          final int students =
              (data['studentsCount'] as int?) ??
              (data['enrolledUsers'] as List<dynamic>? ?? []).length;
          final bool isPaid = data['isPaid'] as bool? ?? false;
          final double price = (data['price'] ?? 0).toDouble();

          learnerCount += students;
          if (isPaid) {
            earnings += students * price;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _DashStatCard(
                  label: 'Courses',
                  value: '$courseCount',
                  icon: Icons.menu_book_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashStatCard(
                  label: 'Students',
                  value: '$learnerCount',
                  icon: Icons.groups_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashStatCard(
                  label: 'Earnings',
                  value: earnings == 0
                      ? '\u20B90'
                      : '\u20B9${earnings.toStringAsFixed(0)}',
                  icon: Icons.attach_money_rounded,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DashStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.teal, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/* --------------------------- courses section --------------------------- */

class _TeacherCoursesSection extends StatelessWidget {
  final String userId;
  const _TeacherCoursesSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('courses')
        .where('teacherId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final docs = snap.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            _AddCourseCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateCourseScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text('You haven\'t created any courses yet.'),
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final title = data['title'] as String? ?? 'Untitled course';
                final desc = data['description'] as String? ?? '';
                final category = data['category'] as String? ?? '';
                final imageUrl = data['imageUrl'] as String? ?? '';
                final students = data['studentsCount'] ?? 0;
                final isPaid = data['isPaid'] as bool? ?? false;
                final price = (data['price'] ?? 0).toDouble();

                return _TeacherCourseCard(
                  title: title,
                  description: desc,
                  category: category,
                  imageUrl: imageUrl,
                  students: students,
                  isPaid: isPaid,
                  price: price,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseDetailScreen(
                          courseId: doc.id,
                          data: data,
                          currentUserId: userId,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
          ],
        );
      },
    );
  }
}

class _AddCourseCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCourseCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.teal.withOpacity(0.6),
            width: 1.4,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.teal.withOpacity(0.3),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.add, size: 34, color: AppColors.teal),
              SizedBox(height: 8),
              Text(
                'Add New Course',
                style: TextStyle(
                  color: AppColors.teal,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherCourseCard extends StatelessWidget {
  final String title;
  final String description;
  final String category;
  final String imageUrl;
  final int students;
  final bool isPaid;
  final double price;
  final VoidCallback onTap;

  const _TeacherCourseCard({
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.students,
    required this.isPaid,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrl.isEmpty
                  ? Container(
                      width: 80,
                      height: 80,
                      color: AppColors.fieldBg,
                      child: const Icon(Icons.image_outlined),
                    )
                  : Image.network(
                      imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.fieldBg,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      const Spacer(),
                      const Icon(Icons.people_outline, size: 14),
                      const SizedBox(width: 3),
                      Text('$students', style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 10),
                      Text(
                        isPaid ? '₹${price.toStringAsFixed(0)}' : 'Free',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPaid
                              ? Colors.green.shade700
                              : Colors.blueGrey,
                        ),
                      ),
                    ],
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

/* --------------------------- learners section --------------------------- */

class _TeacherLearnersSection extends StatelessWidget {
  final String userId;
  const _TeacherLearnersSection({required this.userId});

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _fetchLearnerDocs(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return [];
    final usersRef = FirebaseFirestore.instance.collection('users');
    final futures = userIds.map((id) => usersRef.doc(id).get());
    final snaps = await Future.wait(futures);
    return snaps.where((s) => s.exists).toList();
  }

  @override
  Widget build(BuildContext context) {
    final coursesQuery = FirebaseFirestore.instance
        .collection('courses')
        .where('teacherId', isEqualTo: userId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: coursesQuery.snapshots(),
      builder: (context, courseSnap) {
        if (courseSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (courseSnap.hasError) {
          return Center(child: Text('Error: ${courseSnap.error}'));
        }

        final courseDocs = courseSnap.data?.docs ?? [];
        if (courseDocs.isEmpty) {
          return const Center(
            child: Text('Create a course to start getting learners.'),
          );
        }

        final Set<String> learnerIds = {};
        final Map<String, List<String>> learnerCourses = {};

        for (final doc in courseDocs) {
          final data = doc.data();
          final title = data['title'] as String? ?? 'Untitled course';
          final enrolled = (data['enrolledUsers'] as List<dynamic>? ?? [])
              .cast<String>();
          for (final uid in enrolled) {
            learnerIds.add(uid);
            learnerCourses.putIfAbsent(uid, () => []);
            if (!learnerCourses[uid]!.contains(title)) {
              learnerCourses[uid]!.add(title);
            }
          }
        }

        if (learnerIds.isEmpty) {
          return const Center(child: Text('No learners enrolled yet.'));
        }

        final idsList = learnerIds.toList();

        return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
          future: _fetchLearnerDocs(idsList),
          builder: (context, learnersSnap) {
            if (learnersSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (learnersSnap.hasError) {
              return Center(child: Text('Error: ${learnersSnap.error}'));
            }

            final learners = learnersSnap.data ?? [];
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: learners.length,
              itemBuilder: (context, index) {
                final snap = learners[index];
                final data = snap.data()!;
                final uid = snap.id;

                final name =
                    data['displayName'] as String? ?? 'Unnamed learner';
                final email = data['email'] as String? ?? '';
                final courses = learnerCourses[uid] ?? [];

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.teal,
                      child: Icon(Icons.person_outline, color: Colors.white),
                    ),
                    title: Text(name),
                    subtitle: Text(
                      [
                        if (courses.isNotEmpty)
                          'Courses: ${courses.join(', ')}',
                        if (email.isNotEmpty) email,
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
