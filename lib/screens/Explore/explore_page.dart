import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/screens/Explore/course_ui.dart';
import 'package:skill_link_app/screens/Explore/create_corse.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  Stream<QuerySnapshot> _coursesStream() {
    return FirebaseFirestore.instance
        .collection('courses')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to explore courses')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userStream(user.uid),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Failed to load user profile',
                style: AppTextStyles.body,
              ),
            ),
          );
        }

        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('User data not found')),
          );
        }

        // ✅ this is now safe:
        final userData = userSnap.data!.data() ?? {};
        final intent = (userData['intent'] ?? 'Learn') as String;
        final bool canCreateCourse = intent == 'Teach' || intent == 'Both';

        return Scaffold(
          backgroundColor: const Color(0xfff8f8f8),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            title: const Text(
              'Explore',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: false,
          ),

          // Only teachers / both can see this
          floatingActionButton: canCreateCourse
              ? FloatingActionButton(
                  backgroundColor: AppColors.teal,
                  onPressed: () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateCourseScreen(),
                      ),
                    );
                    if (created == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Course created')),
                      );
                    }
                  },
                  tooltip: 'Create course',
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,

          body: StreamBuilder<QuerySnapshot>(
            stream: _coursesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load courses',
                    style: AppTextStyles.body,
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No courses yet'));
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final title = (data['title'] ?? '') as String;
                  final teacher =
                      (data['teacherName'] ?? data['instructorName'] ?? '')
                          as String;
                  final imageUrl =
                      (data['image'] ?? data['imageUrl'] ?? '') as String;
                  final description = (data['description'] ?? '') as String;

                  return _CourseCard(
                    title: title,
                    teacher: teacher,
                    imageUrl: imageUrl,
                    description: description,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseDetailScreen(
                            courseId: doc.id,
                            data: data,
                            currentUserId: user.uid,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  final String title;
  final String teacher;
  final String imageUrl;
  final String description;
  final VoidCallback onTap;

  const _CourseCard({
    required this.title,
    required this.teacher,
    required this.imageUrl,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 4),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image, size: 40),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    teacher,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        color: Colors.grey.shade800,
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
