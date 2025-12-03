// lib/screens/Explore/module_list_learner.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';

class ModuleListScreen extends StatefulWidget {
  final String courseId;
  final String? courseTitle;

  const ModuleListScreen({required this.courseId, this.courseTitle, super.key});

  @override
  State<ModuleListScreen> createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends State<ModuleListScreen> {
  final _modulesRefBase = FirebaseFirestore.instance;
  String? _uid;
  int _lastOpenedOrder = 0;
  Set<String> _completed = {};
  bool _loadingProgress = true;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    if (_uid == null) {
      setState(() {
        _loadingProgress = false;
        _lastOpenedOrder = 0;
        _completed = {};
      });
      return;
    }

    try {
      final doc = await _modulesRefBase
          .collection('users')
          .doc(_uid)
          .collection('courseProgress')
          .doc(widget.courseId)
          .get();

      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _lastOpenedOrder = (data['lastOpenedOrder'] ?? 0) as int;
          final List<dynamic> comp = data['completedModules'] ?? <dynamic>[];
          _completed = comp.map((e) => e.toString()).toSet();
          _loadingProgress = false;
        });
      } else {
        setState(() {
          _lastOpenedOrder = 0;
          _completed = {};
          _loadingProgress = false;
        });
      }
    } catch (e) {
      debugPrint('Load progress error: $e');
      if (mounted) {
        setState(() {
          _lastOpenedOrder = 0;
          _completed = {};
          _loadingProgress = false;
        });
      }
    }
  }

  Future<void> _updateLastOpenedOrder(int order) async {
    if (_uid == null) return;
    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('courseProgress')
          .doc(widget.courseId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        int current = 0;
        if (snap.exists) {
          current = (snap.data()?['lastOpenedOrder'] ?? 0) as int;
        }
        final newVal = order > current ? order : current;
        tx.set(ref, {
          'lastOpenedOrder': newVal,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (mounted)
        setState(
          () => _lastOpenedOrder = order > _lastOpenedOrder
              ? order
              : _lastOpenedOrder,
        );
    } catch (e) {
      debugPrint('Update lastOpenedOrder failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final modulesStream = FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .collection('modules')
        .orderBy('order')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.courseTitle ?? 'Modules',
          style: const TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: modulesStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting ||
              _loadingProgress) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load modules: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No modules available.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final d = docs[idx];
              final data = d.data();
              final title = (data['title'] ?? 'Untitled Module') as String;
              final desc = (data['description'] ?? '') as String;
              final order = (data['order'] ?? (idx + 1)) as int;
              final moduleId = d.id;
              final isCompleted = _completed.contains(moduleId);

              final isUnlocked = order <= (_lastOpenedOrder + 1);
              final locked = !isUnlocked;

              return Material(
                color: Colors.white,
                child: InkWell(
                  onTap: locked
                      ? () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Module locked'),
                              content: Text(
                                'Finish/open previous modules to unlock Module $order.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      : () async {
                          await _updateLastOpenedOrder(order);

                          final completed = await Navigator.push<bool?>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ModuleContentScreen(
                                courseId: widget.courseId,
                                moduleId: moduleId,
                                moduleOrder: order,
                                moduleTitle: title,
                                moduleDescription: desc,
                              ),
                            ),
                          );

                          if (completed == true) {
                            await _loadProgress();
                          }
                        },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.fieldBg,
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppColors.teal.withOpacity(0.16)
                                : AppColors.teal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '$order',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (isCompleted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.teal.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Completed',
                                        style: TextStyle(
                                          color: AppColors.teal,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                desc,
                                style: AppTextStyles.caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        locked
                            ? const Icon(Icons.lock_outline, color: Colors.grey)
                            : const Icon(
                                Icons.chevron_right,
                                color: Colors.black38,
                              ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ModuleContentScreen extends StatefulWidget {
  final String courseId;
  final String moduleId;
  final int moduleOrder;
  final String moduleTitle;
  final String moduleDescription;

  const ModuleContentScreen({
    required this.courseId,
    required this.moduleId,
    required this.moduleOrder,
    required this.moduleTitle,
    required this.moduleDescription,
    super.key,
  });

  @override
  State<ModuleContentScreen> createState() => _ModuleContentScreenState();
}

class _ModuleContentScreenState extends State<ModuleContentScreen> {
  bool _marking = false;
  bool _isCompleted = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _checkCompleted();
  }

  Future<void> _checkCompleted() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('courseProgress')
          .doc(widget.courseId)
          .get();

      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final List<dynamic> comp =
            doc.data()?['completedModules'] ?? <dynamic>[];
        setState(() {
          _isCompleted = comp
              .map((e) => e.toString())
              .contains(widget.moduleId);
        });
      }
    } catch (e) {
      debugPrint('checkCompleted failed: $e');
    }
  }

  Future<void> _markComplete() async {
    if (_uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be signed in')));
      return;
    }

    setState(() => _marking = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('courseProgress')
          .doc(widget.courseId);

      await ref.set({
        'completedModules': FieldValue.arrayUnion([widget.moduleId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _isCompleted = true);

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Mark complete failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark complete')),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.moduleTitle,
          style: const TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Module ${widget.moduleOrder}',
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 14,
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.moduleTitle,
                      style: AppTextStyles.heading.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.moduleDescription.isNotEmpty
                          ? widget.moduleDescription
                          : 'No description for this module yet.',
                      style: AppTextStyles.body.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection('courses')
                          .doc(widget.courseId)
                          .collection('modules')
                          .doc(widget.moduleId)
                          .get(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const SizedBox();
                        }
                        if (!snap.hasData || !snap.data!.exists)
                          return const SizedBox();
                        final data = snap.data!.data() ?? {};
                        final List<dynamic> lessons = data['lessons'] ?? [];
                        if (lessons.isEmpty) {
                          return const SizedBox();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lessons',
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...lessons.map((l) {
                              final title = (l['title'] ?? 'Lesson') as String;
                              final free = (l['isFree'] ?? false) as bool;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(title),
                                trailing: free
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.teal.withOpacity(
                                            0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Free',
                                          style: TextStyle(
                                            color: AppColors.teal,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    : null,
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isCompleted || _marking
                          ? null
                          : _markComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _marking
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isCompleted ? 'Completed' : 'Mark complete',
                              style: const TextStyle(color: Colors.white),
                            ),
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
