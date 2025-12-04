// lib/screens/Explore/module_list.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';

import 'module_detail.dart';

class ModuleListScreen extends StatelessWidget {
  final String courseId;
  final String courseTitle;

  const ModuleListScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final modulesQuery = FirebaseFirestore.instance
        .collection('courses')
        .doc(courseId)
        .collection('modules')
        .orderBy('order', descending: false);

    final progressDocRef = uid != null
        ? FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('courseProgress')
              .doc(courseId)
        : null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          courseTitle,
          style: AppTextStyles.title.copyWith(fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: modulesQuery.snapshots(),
          builder: (context, modulesSnap) {
            if (modulesSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (modulesSnap.hasError) {
              return Center(
                child: Text('Failed to load modules: ${modulesSnap.error}'),
              );
            }

            final modules = modulesSnap.data?.docs ?? [];

            if (progressDocRef == null) {
              // not logged in
              return Center(
                child: Text(
                  'Please sign in to view modules',
                  style: AppTextStyles.body,
                ),
              );
            }

            // progress stream for this user + course
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: progressDocRef.snapshots(),
              builder: (context, progressSnap) {
                final completedIds = <String>{};
                if (progressSnap.hasData && progressSnap.data!.exists) {
                  final data = progressSnap.data!.data() ?? {};
                  final list =
                      (data['completedModuleIds'] as List<dynamic>?) ??
                      <dynamic>[];
                  for (final v in list) {
                    completedIds.add(v.toString());
                  }
                }

                final total = modules.length;
                final completedCount = completedIds.length;
                final progress = total == 0 ? 0.0 : (completedCount / total);

                return Column(
                  children: [
                    // header: progress bar + counts
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Course progress',
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: AppColors.fieldBg,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('${(progress * 100).round()}%'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$completedCount of $total modules completed',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // module list
                    Expanded(
                      child: modules.isEmpty
                          ? Center(
                              child: Text(
                                'No modules yet — add some from teacher UI',
                                style: AppTextStyles.caption,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: modules.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final doc = modules[index];
                                final data = doc.data();
                                final moduleId = doc.id;
                                final title =
                                    (data['title'] ?? 'Module ${index + 1}')
                                        as String;
                                final desc =
                                    (data['description'] ?? '') as String;
                                final order =
                                    (data['order'] ?? (index + 1)) as int;

                                // lock logic:
                                // first module is always unlocked, otherwise unlocked if previous module id in completedIds
                                final bool isFirst = index == 0;
                                bool unlocked = isFirst;
                                if (!isFirst) {
                                  final prevId = modules[index - 1].id;
                                  unlocked = completedIds.contains(prevId);
                                }

                                final bool completed = completedIds.contains(
                                  moduleId,
                                );

                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 1,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 12,
                                    ),
                                    leading: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: completed
                                          ? AppColors.teal
                                          : AppColors.fieldBg,
                                      child: Text(
                                        '$order',
                                        style: TextStyle(
                                          color: completed
                                              ? Colors.white
                                              : AppColors.teal,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      title,
                                      style: AppTextStyles.subtitle.copyWith(
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: desc.isNotEmpty
                                        ? Text(
                                            desc,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    trailing: unlocked
                                        ? (completed
                                              ? const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                )
                                              : const Icon(
                                                  Icons.lock_open,
                                                  color: AppColors.teal,
                                                ))
                                        : const Icon(
                                            Icons.lock,
                                            color: Colors.grey,
                                          ),
                                    onTap: unlocked
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ModuleDetailScreen(
                                                      courseId: courseId,
                                                      moduleId: moduleId,
                                                      moduleTitle: title,
                                                      moduleDescription: desc,
                                                    ),
                                              ),
                                            );
                                          }
                                        : () {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Complete previous module to unlock this one',
                                                ),
                                              ),
                                            );
                                          },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
