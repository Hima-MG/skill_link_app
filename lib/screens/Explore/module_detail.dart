// lib/screens/Explore/module_detail.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';

class ModuleDetailScreen extends StatefulWidget {
  final String courseId;
  final String moduleId;
  final String moduleTitle;
  final String moduleDescription;

  const ModuleDetailScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.moduleTitle,
    required this.moduleDescription,
  });

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  bool _processing = false;
  String? _uid;
  bool _completed = false;

  DocumentReference<Map<String, dynamic>> get _progressRef {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('courseProgress')
        .doc(widget.courseId);
  }

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _loadCompletedState();
  }

  Future<void> _loadCompletedState() async {
    if (_uid == null) return;
    try {
      final snap = await _progressRef.get();
      if (!mounted) return;
      if (snap.exists) {
        final data = snap.data() ?? {};
        final list = (data['completedModuleIds'] as List<dynamic>?) ?? [];
        setState(
          () => _completed = list
              .map((e) => e.toString())
              .contains(widget.moduleId),
        );
      } else {
        setState(() => _completed = false);
      }
    } catch (e) {
      debugPrint('loadCompletedState error: $e');
    }
  }

  Future<void> _toggleComplete() async {
    if (_uid == null) return;
    setState(() => _processing = true);
    try {
      if (!_completed) {
        // mark complete
        await _progressRef.set({
          'completedModuleIds': FieldValue.arrayUnion([widget.moduleId]),
        }, SetOptions(merge: true));
      } else {
        // unmark
        await _progressRef.set({
          'completedModuleIds': FieldValue.arrayRemove([widget.moduleId]),
        }, SetOptions(merge: true));
      }

      // after updating user's module list, check if they completed all modules -> update course.completedUsers
      final modulesSnap = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('modules')
          .get();

      final total = modulesSnap.docs.length;

      final progressSnap = await _progressRef.get();
      final completedList =
          (progressSnap.data()?['completedModuleIds'] as List<dynamic>?) ?? [];

      final completedCount = completedList.length;

      final courseRef = FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId);
      if (completedCount >= total && total > 0) {
        // add to completedUsers
        await courseRef.set({
          'completedUsers': FieldValue.arrayUnion([_uid]),
        }, SetOptions(merge: true));
      } else {
        // remove from completedUsers (in case user unmarked a module)
        await courseRef.set({
          'completedUsers': FieldValue.arrayRemove([_uid]),
        }, SetOptions(merge: true));
      }

      await _loadCompletedState();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_completed ? 'Marked complete' : 'Marked incomplete'),
        ),
      );
    } catch (e) {
      debugPrint('toggleComplete error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update progress')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.moduleTitle;
    final desc = widget.moduleDescription;

    // measure bottom action area: button height + safe area
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final reservedBottom =
        bottomInset + safeBottom + 90.0; // 90 px reserved for button area

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.title.copyWith(fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 18, 16, reservedBottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - reservedBottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.heading.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        desc.isNotEmpty ? desc : 'No description provided.',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),

      // Place primary action in bottomNavigationBar to avoid clipping / overflow
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _completed
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: AppColors.textLight,
                  ),
            label: Text(
              _completed ? 'Mark incomplete' : 'Mark complete',
              style: TextStyle(color: AppColors.textLight),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _completed ? Colors.redAccent : Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _processing ? null : _toggleComplete,
          ),
        ),
      ),
    );
  }
}
