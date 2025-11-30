// lib/screens/home/home_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  // Auto-scroll controller & timer for trending cards
  late final PageController _trendingController;
  Timer? _autoScrollTimer;

  // Tracking pages & counts for robust wrapping
  int _currentTrendingPage = 0;
  int _trendingCount = 0;

  // simple local liked-state (not saved to Firestore yet)
  final Set<String> _likedPostIds = {};

  // Local fallback placeholder path (uploaded file)
  static const String _localPlaceholder =
      '/mnt/data/Screenshot 2025-11-20 124827.png';

  @override
  void initState() {
    super.initState();
    _trendingController = PageController(viewportFraction: 0.92);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _trendingController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (_trendingCount <= 0) return;
      if (!_trendingController.hasClients) return;

      final next = (_currentTrendingPage + 1) % _trendingCount;
      try {
        _trendingController.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } catch (_) {
        // ignore animation errors if controller not ready
      }
    });
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() {});
  }

  void _onBottomNavTap(int idx) {
    if (idx == _bottomIndex) return;
    setState(() => _bottomIndex = idx);

    switch (idx) {
      case 0:
        // already on home
        break;
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

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 7) return '${dt.day}/${dt.month}/${dt.year}';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
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

  Widget _postCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final authorName = (data['authorName'] ?? 'Unknown') as String;
    final authorAvatar = (data['authorAvatar'] ?? '') as String;
    final authorId = (data['authorId'] ?? '') as String;
    final mediaUrl = (data['media'] ?? '') as String;
    final thumbUrl = (data['thumb'] ?? '') as String;
    final feedImage = thumbUrl.isNotEmpty ? thumbUrl : mediaUrl;
    final title = (data['title'] ?? '') as String;
    final description = (data['description'] ?? '') as String;
    final createdAt = data['createdAt'] as Timestamp?;

    final isLiked = _likedPostIds.contains(doc.id);

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
                    if (authorId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfilePage(userId: authorId),
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
                    backgroundImage: authorAvatar.isNotEmpty
                        ? NetworkImage(authorAvatar)
                        : null,
                    child: authorAvatar.isEmpty
                        ? Text(
                            authorName.isNotEmpty
                                ? authorName[0].toUpperCase()
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
                        authorName,
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdAt != null ? _formatTimestamp(createdAt) : '',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(title, style: AppTextStyles.title.copyWith(fontSize: 16)),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body,
              ),
            ],
            const SizedBox(height: 10),
            if (feedImage.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GestureDetector(
                  onTap: () {
                    final toShow = mediaUrl.isNotEmpty ? mediaUrl : feedImage;
                    if (toShow.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullImageViewer(imageUrl: toShow),
                        ),
                      );
                    }
                  },
                  child: Image.network(
                    feedImage,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 220,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              ),
            if (feedImage.isEmpty) const SizedBox(height: 4),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isLiked) {
                        _likedPostIds.remove(doc.id);
                      } else {
                        _likedPostIds.add(doc.id);
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text('Like', style: AppTextStyles.caption),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => _openComments(doc.id),
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

  Widget _trendingCardLarge(Map<String, dynamic> data) {
    final title = (data['title'] ?? '') as String;
    final teacher = (data['teacherName'] ?? '') as String;
    final img = (data['image'] ?? '') as String;

    Widget imageWidget;
    if (img.isNotEmpty) {
      imageWidget = Image.network(
        img,
        width: 320,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Container(color: Colors.grey.shade200, height: 180),
      );
    } else {
      if (File(_localPlaceholder).existsSync()) {
        imageWidget = Image.file(
          File(_localPlaceholder),
          width: 320,
          height: 180,
          fit: BoxFit.cover,
        );
      } else {
        imageWidget = Container(
          width: 320,
          height: 180,
          color: Colors.grey.shade200,
        );
      }
    }

    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: imageWidget,
          ),
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    teacher,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredIndicators() {
    if (_trendingCount <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_trendingCount, (i) {
          final active = i == _currentTrendingPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 14 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? AppColors.teal : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }),
      ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                      const SizedBox(height: 12),
                      AppWidgets.inputField(
                        controller: _searchCtrl,
                        hint: 'Search skills, posts or people',
                        icon: Icons.search,
                      ),
                      const SizedBox(height: 12),

                      // Trending Skills (auto-scrolling PageView with centered dots)
                      Text(
                        'Trending Skills',
                        style: AppTextStyles.subtitle.copyWith(
                          color: teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 210,
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _trendingCoursesStream(),
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final docs = snap.data?.docs ?? [];

                                // Update internal counters safely after frame
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  if (_trendingCount != docs.length) {
                                    setState(
                                      () => _trendingCount = docs.length,
                                    );
                                    // Ensure current page is within bounds
                                    if (_currentTrendingPage >=
                                            _trendingCount &&
                                        _trendingCount > 0) {
                                      _currentTrendingPage = 0;
                                      _trendingController.jumpToPage(0);
                                    }
                                  }
                                });

                                if (docs.isEmpty) {
                                  return const Center(
                                    child: Text('No trending courses yet'),
                                  );
                                }

                                final currentUid =
                                    FirebaseAuth.instance.currentUser?.uid;

                                return Column(
                                  children: [
                                    SizedBox(
                                      height: 180,
                                      child: PageView.builder(
                                        controller: _trendingController,
                                        itemCount: docs.length,
                                        padEnds: false,
                                        onPageChanged: (idx) {
                                          setState(
                                            () => _currentTrendingPage = idx,
                                          );
                                        },
                                        itemBuilder: (context, index) {
                                          final doc = docs[index];
                                          final data = doc.data();
                                          final courseId = doc.id;

                                          return GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      CourseDetailScreen(
                                                        courseId: courseId,
                                                        data: data,
                                                        currentUserId:
                                                            currentUid,
                                                      ),
                                                ),
                                              );
                                            },
                                            child: _trendingCardLarge(data),
                                          );
                                        },
                                      ),
                                    ),
                                    _buildCenteredIndicators(),
                                  ],
                                );
                              },
                            ),
                      ),
                      const SizedBox(height: 14),

                      // Posts
                      Text(
                        'Posts',
                        style: AppTextStyles.subtitle.copyWith(
                          color: teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refresh,
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _postsStream(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                return ListView(
                                  children: [
                                    Center(
                                      child: Text(
                                        'Failed to load posts',
                                        style: AppTextStyles.body,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              final docs = snapshot.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return ListView(
                                  children: [
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 30),
                                        child: Text(
                                          'No posts yet — create the first one!',
                                          style: AppTextStyles.body,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 24,
                                ),
                                itemCount: docs.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _postCard(docs[index]),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
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
