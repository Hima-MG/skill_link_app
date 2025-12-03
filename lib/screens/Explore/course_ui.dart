// lib/screens/Explore/course_ui.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/screens/Dashboard/dashboard_screen.dart';
import 'package:skill_link_app/screens/chat/chat_screen.dart';
import 'package:skill_link_app/screens/profile/user_profile.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> data;
  final String? currentUserId;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.data,
    required this.currentUserId,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _enrolling = false;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _courseStream() {
    return FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .snapshots();
  }

  Future<void> _enroll(DocumentSnapshot<Map<String, dynamic>> snap) async {
    if (_enrolling) return;

    setState(() => _enrolling = true);

    try {
      final uid =
          widget.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) throw Exception("User not signed in");

      final courseRef = FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId);

      final userEnrollRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('enrollments')
          .doc(widget.courseId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final fresh = await tx.get(courseRef);
        final courseData = fresh.data() ?? {};

        // ensure list is copied to avoid modifying original map reference
        final enrolled = List<String>.from(
          courseData['enrolledUsers'] ?? <String>[],
        );
        final already = enrolled.contains(uid);

        if (!already) {
          tx.update(courseRef, {
            'enrolledUsers': FieldValue.arrayUnion([uid]),
            'studentsCount': (courseData['studentsCount'] ?? 0) + 1,
            'popularity': (courseData['popularity'] ?? 0) + 1,
          });

          tx.set(userEnrollRef, {
            'courseId': widget.courseId,
            'title': courseData['title'] ?? '',
            'teacherName':
                courseData['teacherName'] ??
                courseData['instructorName'] ??
                'Instructor',
            'image': courseData['image'] ?? courseData['imageUrl'] ?? '',
            'enrolledAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enrolled Successfully")));
    } catch (e) {
      debugPrint("Enroll error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to enroll")));
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  void _showMessageOptions({
    required String teacherName,
    required String teacherId,
  }) {
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
                'Message $teacherName',
                style: AppTextStyles.title.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Open chat'),
                subtitle: const Text('Start conversation in SkillLink'),
                onTap: () {
                  Navigator.pop(ctx); // close bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatScreen(peerId: teacherId, peerName: teacherName),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('View full profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(userId: teacherId),
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

  @override
  Widget build(BuildContext context) {
    // compute content bottom padding so content is never hidden by the bottom enroll bar
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    const enrollBarHeight =
        86.0; // approximate height of bottom enroll container
    final contentBottomPadding = bottomSafe + enrollBarHeight + 12.0;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _courseStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: const BackButton(color: Colors.black87),
            ),
            body: const Center(child: Text("Course not found")),
          );
        }

        final data = snap.data!.data() ?? {};

        final String title = data['title'] ?? '';
        final String teacher =
            data['teacherName'] ?? data['instructorName'] ?? 'Instructor';
        final String imageUrl = data['image'] ?? data['imageUrl'] ?? '';
        final String description = data['description'] ?? '';

        final String duration = data['duration'] ?? '1h 30m';
        final int students = (data['studentsCount'] ?? 0) as int;
        final String level = data['level'] ?? 'Beginner';
        final double price = (data['price'] ?? 0).toDouble();
        final String? category = data['category'] as String?;
        final String? teacherId = data['teacherId'] as String?;

        final String? uid =
            widget.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;

        final List enrolledUsers = data['enrolledUsers'] ?? [];
        final bool isEnrolled = uid != null && enrolledUsers.contains(uid);

        final String buttonLabel = isEnrolled
            ? "Go to course"
            : "Enroll to the course";

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ---------- Header ----------
                  SliverAppBar(
                    expandedHeight: 240,
                    pinned: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    leading: const BackButton(color: Colors.black87),
                    // give rounded bottom so background image appears rounded
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(26),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(26),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            imageUrl.isNotEmpty
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey.shade300,
                                    child: const Center(
                                      child: Icon(Icons.image, size: 40),
                                    ),
                                  ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.08),
                                    Colors.black.withOpacity(0.35),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ---------- Content ----------
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        contentBottomPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            title,
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 23,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Teacher section with avatar from Firestore
                          if (teacherId != null)
                            _TeacherHeader(
                              teacherId: teacherId,
                              fallbackName: teacher,
                              onTapProfile: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProfilePage(userId: teacherId),
                                  ),
                                );
                              },
                            )
                          else
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey.shade300,
                                  child: const Icon(Icons.person, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      teacher,
                                      style: AppTextStyles.subtitle.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                          const SizedBox(height: 18),

                          // Info chips row
                          Row(
                            children: [
                              _infoChip(icon: Icons.schedule, label: duration),
                              const SizedBox(width: 8),
                              _infoChip(
                                icon: Icons.group_outlined,
                                label: '$students students',
                              ),
                              const SizedBox(width: 8),
                              _pillChip(label: level),
                              const Spacer(),
                              if (price > 0)
                                Text(
                                  '₹${price.toStringAsFixed(0)}',
                                  style: AppTextStyles.subtitle.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              else
                                Text(
                                  'Free',
                                  style: AppTextStyles.subtitle.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // About
                          Text(
                            'About this course',
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description.isNotEmpty
                                ? description
                                : 'No description available.',
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),

                          const SizedBox(height: 24),

                          // Related courses
                          if (category != null && category.trim().isNotEmpty)
                            _RelatedCoursesSection(
                              currentCourseId: widget.courseId,
                              category: category,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ---------- Bottom Enroll Button ----------
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isEnrolled
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DashboardScreen(),
                                ),
                              )
                            : _enrolling
                            ? null
                            : () => _enroll(snap.data!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _enrolling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                buttonLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              // ---------- Floating Message Teacher Button ----------
              if (teacherId != null)
                Positioned(
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 100,
                  child: FloatingActionButton.extended(
                    heroTag: 'message_teacher_btn',
                    onPressed: () {
                      _showMessageOptions(
                        teacherName: teacher,
                        teacherId: teacherId,
                      );
                    },
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.teal,
                    elevation: 4,
                    label: const Text('Message'),
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------- UI Components ----------
  Widget _infoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xfff2f5f7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _pillChip({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.fieldBg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  final String teacherId;
  final String fallbackName;
  final VoidCallback onTapProfile;

  const _TeacherHeader({
    required this.teacherId,
    required this.fallbackName,
    required this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(teacherId)
        .get();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: userDoc,
      builder: (context, snap) {
        String name = fallbackName;
        String avatarUrl = '';
        String headline = '';

        if (snap.hasData && snap.data!.data() != null) {
          final data = snap.data!.data()!;
          name =
              (data['displayName'] ?? data['name'] ?? fallbackName) as String;
          avatarUrl = (data['avatarUrl'] ?? '') as String;
          headline = (data['headline'] ?? '') as String;
        }

        return InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTapProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                backgroundColor: Colors.grey.shade300,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal,
                    ),
                  ),
                  if (headline.isNotEmpty)
                    Text(
                      headline,
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'View instructor profile',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black45),
            ],
          ),
        );
      },
    );
  }
}

class _RelatedCoursesSection extends StatelessWidget {
  final String currentCourseId;
  final String category;

  const _RelatedCoursesSection({
    required this.currentCourseId,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('courses')
        .where('category', isEqualTo: category)
        .limit(10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related courses',
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              if (snap.hasError) {
                return const Text('Failed to load related courses');
              }

              final docs = (snap.data?.docs ?? [])
                  .where((d) => d.id != currentCourseId)
                  .toList();

              if (docs.isEmpty) {
                return Text(
                  'No related courses found.',
                  style: AppTextStyles.caption,
                );
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final d = docs[index];
                  final data = d.data();
                  final title = data['title'] as String? ?? 'Untitled course';
                  final imageUrl =
                      data['imageUrl'] as String? ?? data['image'] ?? '';
                  final teacherName =
                      data['teacherName'] as String? ?? 'Instructor';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseDetailScreen(
                            courseId: d.id,
                            data: data,
                            currentUserId:
                                FirebaseAuth.instance.currentUser?.uid,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xfff8f8f8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: imageUrl.isEmpty
                                ? Container(
                                    height: 90,
                                    color: AppColors.fieldBg,
                                    child: const Icon(Icons.image_outlined),
                                  )
                                : Image.network(
                                    imageUrl,
                                    height: 90,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  teacherName,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
