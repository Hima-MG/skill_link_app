// lib/screens/modules/module_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';

class ModulePage extends StatefulWidget {
  final String courseId;
  const ModulePage({required this.courseId, super.key});

  @override
  State<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends State<ModulePage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  CollectionReference<Map<String, dynamic>> get _modulesRef => FirebaseFirestore
      .instance
      .collection('courses')
      .doc(widget.courseId)
      .collection('modules');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _addModule() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      // compute next order value
      final snapshot = await _modulesRef
          .orderBy('order', descending: true)
          .limit(1)
          .get();
      int nextOrder = 1;
      if (snapshot.docs.isNotEmpty) {
        final d = snapshot.docs.first.data();
        final int existing = (d['order'] ?? 0) as int;
        nextOrder = existing + 1;
      }

      await _modulesRef.add({
        'title': title,
        'description': desc,
        'order': nextOrder,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _titleCtrl.clear();
      _descCtrl.clear();
      FocusScope.of(context).unfocus();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Module added')));
      }
    } catch (e) {
      debugPrint('Add module error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add module: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteModule(String moduleId) async {
    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete module'),
        content: const Text(
          'Are you sure you want to delete this module? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (should != true) return;

    try {
      await _modulesRef.doc(moduleId).delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Module deleted')));
      }
    } catch (e) {
      debugPrint('Delete module error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete module')),
        );
      }
    }
  }

  Future<void> _editModule(
    String moduleId,
    String currentTitle,
    String currentDesc,
  ) async {
    _titleCtrl.text = currentTitle;
    _descCtrl.text = currentDesc;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Module'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final newTitle = _titleCtrl.text.trim();
    final newDesc = _descCtrl.text.trim();
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title cannot be empty')));
      return;
    }

    try {
      await _modulesRef.doc(moduleId).set({
        'title': newTitle,
        'description': newDesc,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _titleCtrl.clear();
      _descCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Module updated')));
      }
    } catch (e) {
      debugPrint('Edit module error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update module')),
        );
      }
    }
  }

  void _openModuleNotes(String title, String description) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ModuleNotesPage(title: title, description: description),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modulesStream = _modulesRef.orderBy('order').snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modules', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Add module area (simple, aesthetic)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.fieldBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Module title (e.g. Module 1 - Beginner)',
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _descCtrl,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Short description (optional)',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.fieldBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saving ? null : _addModule,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.add, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // modules list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: modulesStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No modules yet — add your first module'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final m = doc.data();
                    final title = (m['title'] ?? '') as String;
                    final desc = (m['description'] ?? '') as String;
                    final order = (m['order'] ?? (i + 1)) as int;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openModuleNotes(title, desc),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.teal.withOpacity(
                                  0.12,
                                ),
                                child: Text(
                                  '$order',
                                  style: TextStyle(
                                    color: AppColors.teal,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        desc,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (val) async {
                                  if (val == 'edit') {
                                    await _editModule(doc.id, title, desc);
                                  } else if (val == 'delete') {
                                    await _deleteModule(doc.id);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                                icon: const Icon(Icons.more_vert),
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
          ),
        ],
      ),
    );
  }
}

class _ModuleNotesPage extends StatelessWidget {
  final String title;
  final String description;
  const _ModuleNotesPage({
    required this.title,
    required this.description,
    // ignore: unused_element_parameter
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: description.isEmpty
            ? const Center(child: Text('No notes for this module yet.'))
            : SingleChildScrollView(
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
      ),
    );
  }
}
