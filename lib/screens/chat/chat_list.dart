import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/screens/chat/chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to see messages')),
      );
    }

    final uid = user.uid;

    final chatsQuery = FirebaseFirestore.instance
        .collection('chats')
        .where('members', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: Text(
          'Messages',
          style: AppTextStyles.heading.copyWith(fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chatsQuery.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load chats: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No conversations yet.\nStart messaging from profiles or courses.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final chatDoc = docs[index];
              final data = chatDoc.data();

              final members = (data['members'] as List<dynamic>? ?? [])
                  .cast<String>();
              if (members.length < 2) return const SizedBox.shrink();

              final otherId = members.firstWhere(
                (m) => m != uid,
                orElse: () => '',
              );

              if (otherId.isEmpty) return const SizedBox.shrink();

              final lastMessage = data['lastMessage'] as String? ?? '';
              final lastTs = data['lastMessageAt'];

              return _ChatListItem(
                otherUserId: otherId,
                lastMessage: lastMessage,
                lastMessageAt: lastTs is Timestamp ? lastTs.toDate() : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatListItem extends StatelessWidget {
  final String otherUserId;
  final String lastMessage;
  final DateTime? lastMessageAt;

  const _ChatListItem({
    required this.otherUserId,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(otherUserId);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: userRef.get(),
      builder: (context, snap) {
        String name = 'User';
        String avatarUrl = '';

        if (snap.hasData && snap.data!.data() != null) {
          final data = snap.data!.data()!;
          name = (data['displayName'] ?? data['name'] ?? 'User') as String;
          avatarUrl = (data['avatarUrl'] ?? '') as String;
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 4,
          ),
          leading: CircleAvatar(
            radius: 22,
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            backgroundColor: AppColors.fieldBg,
            child: avatarUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            lastMessage.isEmpty ? 'Tap to start chatting' : lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
          trailing: Text(
            _formatTime(lastMessageAt),
            style: AppTextStyles.caption.copyWith(fontSize: 10),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  peerId: otherUserId,
                  peerName: name,
                  peerAvatarUrl: avatarUrl,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
