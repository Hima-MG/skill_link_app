import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/screens/Explore/course_ui.dart';
import 'package:skill_link_app/screens/Explore/create_corse.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _categories = [
    'All',
    'Development',
    'Programming',
    'Arts',
    'Dance',
    'Design',
    'Business',
    'Music',
    'Health and Fitness',
  ];

  late final TabController _tabController;

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
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _enroll(String courseId, String uid) async {
    final courseRef = FirebaseFirestore.instance
        .collection('courses')
        .doc(courseId);
    final studentRef = courseRef.collection('students').doc(uid);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final courseSnap = await tx.get(courseRef);
        final currentCount = (courseSnap.data()?['enrolledCount'] ?? 0) as int;
        tx.set(studentRef, {'enrolledAt': FieldValue.serverTimestamp()});
        tx.update(courseRef, {'enrolledCount': currentCount + 1});
      });
    } catch (e) {
      debugPrint('Enroll failed: $e');
      rethrow;
    }
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

        final userData = userSnap.data!.data() ?? {};
        final intent = (userData['intent'] ?? 'Learn') as String;
        final bool canCreateCourse = intent == 'Teach' || intent == 'Both';
        final bool canEnrollGlobally = intent == 'Learn' || intent == 'Both';

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
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.teal,
              unselectedLabelColor: Colors.grey.shade700,
              indicatorColor: AppColors.teal,
              tabs: _categories.map((c) => Tab(text: c)).toList(),
            ),
          ),
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

              return TabBarView(
                controller: _tabController,
                children: _categories.map((category) {
                  final filtered = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final cat = (data['category'] ?? '').toString();
                    if (category == 'All') return true;
                    return cat.toLowerCase() == category.toLowerCase();
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(child: Text('No courses in "$category"'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['title'] ?? '') as String;
                      final teacher =
                          (data['teacherName'] ?? data['instructorName'] ?? '')
                              as String;
                      final imageUrl =
                          (data['image'] ?? data['imageUrl'] ?? '') as String;
                      final description = (data['description'] ?? '') as String;

                      return _CourseCardWithEnroll(
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
                        courseId: doc.id,
                        currentUserId: user.uid,
                        canEnrollGlobally: canEnrollGlobally,
                        enrollCallback: () async {
                          try {
                            await _enroll(doc.id, user.uid);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enrolled successfully'),
                              ),
                            );
                            setState(() {}); // refresh enroll status
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to enroll: $e')),
                            );
                          }
                        },
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        );
      },
    );
  }
}

class _CourseCardWithEnroll extends StatelessWidget {
  final String title;
  final String teacher;
  final String imageUrl;
  final String description;
  final VoidCallback onTap;
  final String courseId;
  final String currentUserId;
  final bool canEnrollGlobally;
  final Future<void> Function() enrollCallback;

  const _CourseCardWithEnroll({
    required this.title,
    required this.teacher,
    required this.imageUrl,
    required this.description,
    required this.onTap,
    required this.courseId,
    required this.currentUserId,
    required this.canEnrollGlobally,
    required this.enrollCallback,
  });

  Future<bool> _isEnrolled() async {
    final snap = await FirebaseFirestore.instance
        .collection('courses')
        .doc(courseId)
        .collection('students')
        .doc(currentUserId)
        .get();
    return snap.exists;
  }

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
                  const SizedBox(height: 12),
                  FutureBuilder<bool>(
                    future: _isEnrolled(),
                    builder: (context, enrolledSnap) {
                      final enrolled = enrolledSnap.data ?? false;

                      if (enrolled) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: const Text(
                              'Enrolled',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }

                      return Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: canEnrollGlobally
                              ? () async {
                                  try {
                                    await enrollCallback();
                                  } catch (_) {
                                    // errors handled in callback
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canEnrollGlobally
                                ? AppColors.teal
                                : Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            canEnrollGlobally
                                ? 'Enroll'
                                : 'Teachers cannot enroll',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
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
