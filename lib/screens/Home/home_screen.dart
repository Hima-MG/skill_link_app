import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/core/app_widget.dart';
import 'package:skill_link_app/screens/Explore/course_ui.dart';
import 'package:skill_link_app/screens/Explore/explore_page.dart';
import 'package:skill_link_app/screens/post/create_post.dart';
import 'package:skill_link_app/screens/profile/user_profile.dart';
import 'package:skill_link_app/screens/chat/chat_list.dart';
import 'package:skill_link_app/screens/Dashboard/dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  int _bottomIndex = 0;

  // current search text (lowercased)
  String _searchTerm = '';

  // Local fallback placeholder path (optional)
  static const String _localPlaceholder =
      '/mnt/data/Screenshot 2025-11-20 124827.png';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchTerm = _searchCtrl.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onBottomNavTap(int idx) {
    // For home tab, we just set index (no navigation)
    if (idx == 0) {
      if (_bottomIndex != 0) {
        setState(() => _bottomIndex = 0);
      }
      return;
    }

    // For other tabs, we only navigate, we keep bottomIndex = 0
    // so when we pop back, Home remains highlighted.
    switch (idx) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExploreScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatListScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        break;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _trendingCoursesStream() {
    return FirebaseFirestore.instance
        .collection('courses')
        .orderBy('popularity', descending: true)
        .limit(10)
        .snapshots();
  }

  void _openComments(String postId) {
    final commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            bottom: bottomInset,
            left: 16,
            right: 16,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Comments',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 260,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(postId)
                      .collection('comments')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No comments yet. Be the first!'),
                      );
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data =
                            docs[i].data() as Map<String, dynamic>? ?? {};
                        final text = (data['text'] ?? '') as String;
                        final name = (data['authorName'] ?? 'User') as String;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.grey.shade200,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      text,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final text = commentCtrl.text.trim();
                      if (text.isEmpty) return;
                      final user = FirebaseAuth.instance.currentUser;
                      await FirebaseFirestore.instance
                          .collection('posts')
                          .doc(postId)
                          .collection('comments')
                          .add({
                            'text': text,
                            'authorId': user?.uid ?? '',
                            'authorName': user?.displayName ?? 'Unknown',
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                      commentCtrl.clear();
                    },
                    child: const Text('Post'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPostOptions(
    BuildContext context, {
    required String postId,
    required Map<String, dynamic> postData,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.report_outlined,
                  color: Colors.redAccent,
                ),
                title: const Text('Report content'),
                subtitle: const Text(
                  'Report this post for inappropriate content',
                ),
                onTap: () async {
                  Navigator.of(ctx).pop(); // close bottom sheet
                  // open confirmation dialog with optional reason
                  final reasonCtrl = TextEditingController();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dctx) {
                      return AlertDialog(
                        title: const Text('Report post'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Are you sure you want to report this post? You can provide a short reason (optional).',
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: reasonCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Reason (optional)',
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.teal,
                            ),
                            onPressed: () => Navigator.of(dctx).pop(true),
                            child: const Text(
                              'Report',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmed != true) {
                    // user cancelled
                    return;
                  }

                  final reason = reasonCtrl.text.trim();

                  // Save report to Firestore
                  try {
                    await FirebaseFirestore.instance.collection('reports').add({
                      'postId': postId,
                      'postSnapshot': postData,
                      'reportedBy': currentUser?.uid ?? '',
                      'reportedByName': currentUser?.displayName ?? '',
                      'reason': reason,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report submitted — thank you.'),
                      ),
                    );
                  } catch (e) {
                    debugPrint('Failed to submit report: $e');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Failed to submit report. Please try again later.',
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.black87),
                title: const Text('Block user'),
                subtitle: const Text('Stop seeing posts from this user'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  // Persist block in a 'blocks' collection (optional)
                  final currentUid =
                      FirebaseAuth.instance.currentUser?.uid ?? '';
                  final authorId =
                      postData['authorId'] ?? postData['userId'] ?? '';
                  if (currentUid.isNotEmpty && authorId.isNotEmpty) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUid)
                          .collection('blockedUsers')
                          .doc(authorId)
                          .set({'blockedAt': FieldValue.serverTimestamp()});
                    } catch (e) {
                      debugPrint('Failed to block user: $e');
                    }
                  }

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('User blocked')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () {
                  Navigator.of(ctx).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share feature coming soon')),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final teal = AppColors.teal;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.fieldBg,
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: AppColors.fieldBg,
        elevation: 4,
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreatePost()),
          );
          if (created == true) {
            if (mounted) setState(() {});
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Post created')));
          }
        },
        child: const Icon(Icons.add, color: Colors.teal),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: IconButton(
                  onPressed: () => _onBottomNavTap(0),
                  icon: Icon(
                    Icons.home_outlined,
                    color: _bottomIndex == 0 ? teal : Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: () => _onBottomNavTap(1),
                  icon: Icon(
                    Icons.explore_outlined,
                    color: _bottomIndex == 1 ? teal : Colors.grey,
                  ),
                ),
              ),
              const Expanded(child: SizedBox()), // FAB gap
              Expanded(
                child: IconButton(
                  onPressed: () => _onBottomNavTap(2),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: _bottomIndex == 2 ? teal : Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: () => _onBottomNavTap(3),
                  icon: Icon(
                    Icons.dashboard_outlined,
                    color: _bottomIndex == 3 ? teal : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, outer) {
            final horizontalPadding = outer.maxWidth < 420 ? 12.0 : 20.0;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: min(920, outer.maxWidth),
                  ),
                  child: CustomScrollView(
                    slivers: [
                      // header row
                      SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Home',
                                style: AppTextStyles.heading.copyWith(
                                  fontSize: 28,
                                  color: teal,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfilePage(),
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage:
                                    user?.photoURL != null &&
                                        user!.photoURL!.isNotEmpty
                                    ? NetworkImage(user.photoURL!)
                                    : null,
                                child:
                                    (user?.photoURL == null ||
                                        user!.photoURL!.isEmpty)
                                    ? Text(
                                        user?.displayName
                                                ?.substring(0, 1)
                                                .toUpperCase() ??
                                            '?',
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SliverToBoxAdapter(child: const SizedBox(height: 12)),

                      // search
                      SliverToBoxAdapter(
                        child: AppWidgets.inputField(
                          controller: _searchCtrl,
                          hint: 'Search skills, posts or people',
                          icon: Icons.search,
                        ),
                      ),

                      SliverToBoxAdapter(child: const SizedBox(height: 12)),

                      // Trending title
                      SliverToBoxAdapter(
                        child: Text(
                          'Trending Skills',
                          style: AppTextStyles.subtitle.copyWith(
                            color: teal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(child: const SizedBox(height: 12)),

                      // Trending Carousel (wrapped in StreamBuilder)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 210,
                          child:
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: _trendingCoursesStream(),
                                builder: (context, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  final docs = snap.data?.docs ?? [];

                                  // Apply search filter to courses
                                  List<
                                    QueryDocumentSnapshot<Map<String, dynamic>>
                                  >
                                  filteredDocs = docs;
                                  if (_searchTerm.isNotEmpty) {
                                    filteredDocs = docs.where((doc) {
                                      final data = doc.data();
                                      final title =
                                          (data['title'] ?? '') as String? ??
                                          '';
                                      final teacher =
                                          (data['teacherName'] ??
                                                  data['authorName'] ??
                                                  '')
                                              as String? ??
                                          '';
                                      final combined = '$title $teacher'
                                          .toLowerCase();
                                      return combined.contains(_searchTerm);
                                    }).toList();
                                  }

                                  if (filteredDocs.isEmpty) {
                                    return Center(
                                      child: Text(
                                        _searchTerm.isEmpty
                                            ? 'No trending courses yet'
                                            : 'No courses match your search',
                                      ),
                                    );
                                  }

                                  final currentUid =
                                      FirebaseAuth.instance.currentUser?.uid;

                                  final items = filteredDocs.map((doc) {
                                    final data = doc.data();
                                    final courseId = doc.id;
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CourseDetailScreen(
                                              courseId: courseId,
                                              data: data,
                                              currentUserId: currentUid,
                                            ),
                                          ),
                                        );
                                      },
                                      child: _trendingCardLarge(data),
                                    );
                                  }).toList();

                                  return CarouselSlider(
                                    items: items,
                                    options: CarouselOptions(
                                      height: 180,
                                      enlargeCenterPage: true,
                                      viewportFraction: 0.88,
                                      enableInfiniteScroll: false,
                                      padEnds: false,
                                    ),
                                  );
                                },
                              ),
                        ),
                      ),

                      SliverToBoxAdapter(child: const SizedBox(height: 14)),

                      // Posts title
                      SliverToBoxAdapter(
                        child: Text(
                          'Posts',
                          style: AppTextStyles.subtitle.copyWith(
                            color: teal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(child: const SizedBox(height: 8)),

                      // Posts stream -> SliverList
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _postsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snapshot.hasError) {
                            return SliverToBoxAdapter(
                              child: Center(
                                child: Text(
                                  'Failed to load posts',
                                  style: AppTextStyles.body,
                                ),
                              ),
                            );
                          }
                          final docs = snapshot.data?.docs ?? [];

                          // Apply search filter to posts
                          List<QueryDocumentSnapshot<Map<String, dynamic>>>
                          filteredDocs = docs;
                          if (_searchTerm.isNotEmpty) {
                            filteredDocs = docs.where((doc) {
                              final data = doc.data();
                              final title =
                                  (data['title'] ?? '') as String? ?? '';
                              final desc =
                                  (data['content'] ??
                                          data['description'] ??
                                          data['caption'] ??
                                          data['text'] ??
                                          '')
                                      as String? ??
                                  '';
                              final author =
                                  (data['authorName'] ??
                                          data['author'] ??
                                          data['author_displayName'] ??
                                          '')
                                      as String? ??
                                  '';
                              final combined = '$title $desc $author'
                                  .toLowerCase();
                              return combined.contains(_searchTerm);
                            }).toList();
                          }

                          if (filteredDocs.isEmpty) {
                            return SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 30),
                                  child: Text(
                                    _searchTerm.isEmpty
                                        ? 'No posts yet — create the first one!'
                                        : 'No posts match your search',
                                    style: AppTextStyles.body,
                                  ),
                                ),
                              ),
                            );
                          }

                          return SliverList(
                            key: const PageStorageKey('postsList'),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final doc = filteredDocs[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: PostCard(
                                  key: ValueKey(doc.id),
                                  doc: doc,
                                  openComments: _openComments,
                                  showPostOptions: _showPostOptions,
                                  localPlaceholder: _localPlaceholder,
                                ),
                              );
                            }, childCount: filteredDocs.length),
                          );
                        },
                      ),

                      // bottom spacing
                      SliverToBoxAdapter(child: const SizedBox(height: 24)),
                    ],
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

Widget _trendingCardLarge(Map<String, dynamic> data) {
  final title = (data['title'] ?? '') as String;
  final teacher = (data['teacherName'] ?? data['authorName'] ?? '') as String;
  final img = (data['image'] ?? data['thumbnailUrl'] ?? '') as String;

  return Container(
    width: 320,
    margin: const EdgeInsets.only(right: 12),
    child: Stack(
      children: [
        // IMAGE
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: img.isNotEmpty
              ? Image.network(
                  img,
                  width: 320,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey.shade200, height: 180),
                )
              : Container(width: 320, height: 180, color: Colors.grey.shade200),
        ),

        // TEXT OVERLAY
        Positioned(
          left: 12,
          bottom: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  teacher,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class PostCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final void Function(String postId) openComments;
  final Future<void> Function(
    BuildContext context, {
    required String postId,
    required Map<String, dynamic> postData,
  })
  showPostOptions;
  final String localPlaceholder;

  const PostCard({
    required Key key,
    required this.doc,
    required this.openComments,
    required this.showPostOptions,
    required this.localPlaceholder,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late Map<String, dynamic> _data;
  late String _authorName;
  late String _authorAvatar;
  late String _authorId;
  late String _mediaUrl;
  late String _description;
  late String _title;
  DateTime? _created;
  bool _isLiked = false;
  int _likesCount = 0;
  bool _loadingLikeState = true;
  bool _processingLike = false;

  @override
  void initState() {
    super.initState();
    _initFromDoc(widget.doc);
    _loadInitialLikeState();
  }

  void _initFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    _data = doc.data();
    _authorName =
        (_data['authorName'] ??
                _data['author'] ??
                _data['author_displayName'] ??
                'Unknown')
            as String;
    _authorAvatar =
        (_data['authorAvatar'] ?? _data['avatarUrl'] ?? _data['avatar'] ?? '')
            as String;
    _authorId = (_data['userId'] ?? _data['authorId'] ?? '') as String;
    _mediaUrl =
        (_data['imageUrl'] ??
                _data['media'] ??
                _data['thumb'] ??
                _data['image'] ??
                '')
            as String;
    _description =
        (_data['content'] ??
                _data['description'] ??
                _data['caption'] ??
                _data['text'] ??
                '')
            as String;
    _title = (_data['title'] ?? '') as String;

    final createdRaw = _data['createdAt'];
    if (createdRaw is Timestamp) {
      _created = createdRaw.toDate();
    } else if (createdRaw is DateTime) {
      _created = createdRaw;
    }

    _likesCount = (_data['likesCount'] ?? 0) as int;
  }

  // If parent rebuilds with a new doc for same id, avoid overwriting local like state.
  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc.id != widget.doc.id) {
      // new post entirely -> reinitialize
      _initFromDoc(widget.doc);
      _loadInitialLikeState();
    } else {
      // same post id: update non-like fields (title/desc/media) but keep user-local like info
      final newData = widget.doc.data();
      final newMedia =
          (newData['imageUrl'] ??
                  newData['media'] ??
                  newData['thumb'] ??
                  newData['image'] ??
                  '')
              as String;
      final newTitle = (newData['title'] ?? '') as String;
      final newDesc =
          (newData['content'] ??
                  newData['description'] ??
                  newData['caption'] ??
                  newData['text'] ??
                  '')
              as String;
      final newLikesCount = (newData['likesCount'] ?? 0) as int;

      setState(() {
        _mediaUrl = newMedia;
        _title = newTitle;
        _description = newDesc;

        if (!_processingLike) _likesCount = newLikesCount;
      });
    }
  }

  Future<void> _loadInitialLikeState() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLiked = false;
        _loadingLikeState = false;
      });
      return;
    }
    try {
      final likeSnap = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.doc.id)
          .collection('likes')
          .doc(uid)
          .get();
      if (!mounted) return;
      setState(() {
        _isLiked = likeSnap.exists;
        _loadingLikeState = false;
      });
    } catch (e) {
      debugPrint('Failed to load like state for ${widget.doc.id}: $e');
      if (!mounted) return;
      setState(() {
        _isLiked = false;
        _loadingLikeState = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // maybe show a login prompt
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to like posts')),
      );
      return;
    }

    if (_processingLike) return;
    setState(() {
      _processingLike = true;
      // optimistic UI update
      if (_isLiked) {
        _isLiked = false;
        _likesCount = (_likesCount - 1).clamp(0, 999999);
      } else {
        _isLiked = true;
        _likesCount = _likesCount + 1;
      }
    });

    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.doc.id);
    final likeRef = postRef.collection('likes').doc(uid);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(postRef);
        final current = (snap.data()?['likesCount'] ?? 0) as int;
        if (_isLiked) {
          // add like
          tx.update(postRef, {'likesCount': current + 1});
          tx.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
        } else {
          // remove like
          tx.update(postRef, {'likesCount': (current - 1).clamp(0, 999999)});
          tx.delete(likeRef);
        }
      });
    } catch (e) {
      debugPrint('Like transaction failed for ${widget.doc.id}: $e');
      // rollback optimistic change on error
      if (!mounted) return;
      setState(() {
        if (_isLiked) {
          // we thought we liked, revert
          _isLiked = false;
          _likesCount = (_likesCount - 1).clamp(0, 999999);
        } else {
          _isLiked = true;
          _likesCount = _likesCount + 1;
        }
      });
    } finally {
      if (mounted) setState(() => _processingLike = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use local cached fields to avoid rebuild flicker when parent updates.
    final created = _created;
    final createdText = created != null ? _formatTimestampLocal(created) : '';

    Widget imageWidget;
    if (_mediaUrl.isNotEmpty) {
      imageWidget = Image.network(
        _mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 220,
        errorBuilder: (_, __, ___) => Container(
          height: 220,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image)),
        ),
      );
    } else {
      if (File(widget.localPlaceholder).existsSync()) {
        imageWidget = Image.file(
          File(widget.localPlaceholder),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 220,
        );
      } else {
        imageWidget = Container(height: 220, color: Colors.grey.shade200);
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_authorId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfilePage(userId: _authorId),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _authorAvatar.isNotEmpty
                        ? NetworkImage(_authorAvatar)
                        : null,
                    child: _authorAvatar.isEmpty
                        ? Text(
                            _authorName.isNotEmpty
                                ? _authorName[0].toUpperCase()
                                : '?',
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _authorName,
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(createdText, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    widget.showPostOptions(
                      context,
                      postId: widget.doc.id,
                      postData: _data,
                    );
                  },
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            if (_title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_title, style: AppTextStyles.title.copyWith(fontSize: 16)),
            ],
            if (_description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body,
              ),
            ],
            const SizedBox(height: 10),
            if (_mediaUrl.isNotEmpty || widget.localPlaceholder.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GestureDetector(
                  onDoubleTap: () async {
                    await _toggleLike();
                  },
                  onTap: () {
                    final toShow = _mediaUrl;
                    if (toShow.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullImageViewer(imageUrl: toShow),
                        ),
                      );
                    }
                  },
                  child: imageWidget,
                ),
              ),
            if (_mediaUrl.isEmpty) const SizedBox(height: 4),
            const SizedBox(height: 10),
            Row(
              children: [
                // Like button (uses local optimistic state)
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.grey,
                  ),
                  onPressed: _loadingLikeState
                      ? null
                      : () async => await _toggleLike(),
                ),
                const SizedBox(width: 8),
                Text('$_likesCount', style: AppTextStyles.caption),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => widget.openComments(widget.doc.id),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text('Comment', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestampLocal(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 7) return '${dt.day}/${dt.month}/${dt.year}';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// lightweight full image viewer (keeps the file self-contained)
class FullImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullImageViewer({required this.imageUrl, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
