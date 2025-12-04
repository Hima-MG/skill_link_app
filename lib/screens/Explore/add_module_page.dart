// lib/screens/Explore/add_module_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';

class AddModulePage extends StatefulWidget {
  final String courseId;
  const AddModulePage({required this.courseId, super.key});

  @override
  State<AddModulePage> createState() => _AddModulePageState();
}

class _AddModulePageState extends State<AddModulePage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  CollectionReference<Map<String, dynamic>> get _modulesRef => FirebaseFirestore
      .instance
      .collection('courses')
      .doc(widget.courseId)
      .collection('modules');

  Future<void> _addModule() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
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
        'lessons': [], // start empty; instructors can add lessons later
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add module: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Module',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Module title',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.fieldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'e.g., Module 1 - Beginner',
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Short description (optional)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.fieldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Describe what learners will find in this module',
                ),
                maxLines: 4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _addModule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Add module',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
