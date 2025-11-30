import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skill_link_app/core/app_color.dart';

import 'package:skill_link_app/core/app_widget.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _pickedFile;
  bool _loading = false;
  String? _error;
  String? _selectedCategory;
  bool _isPaid = false;
  double _price = 0;

  final List<String> _categories = [
    'Dance',
    'Development',
    'Design',
    'Business',
    'Photography',
    'Music',
    'Marketing',
    'Health & Fitness',
    'Language',
    'Personal Development',
  ];

  // Cloudinary config
  static const String _cloudName = 'duando6bf';
  static const String _uploadPreset = 'SkillLink';

  Future<String?> _uploadToCloudinary(File file) async {
    try {
      final cloudinary = CloudinaryPublic(
        _cloudName,
        _uploadPreset,
        cache: false,
      );
      final res = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'skilllink_courses',
        ),
      );
      return res.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }

  Future<void> _pickImage(ImageSource src) async {
    final picked = await _picker.pickImage(
      source: src,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() {
      _pickedFile = File(picked.path);
    });
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      setState(() => _error = 'Please select a category');
      return;
    }

    if (_isPaid && _price <= 0) {
      setState(() => _error = 'Please set a valid price for paid course');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');

      String imageUrl = '';
      if (_pickedFile != null) {
        final url = await _uploadToCloudinary(_pickedFile!);
        if (url == null) throw Exception('Image upload failed');
        imageUrl = url;
      }

      final courseData = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _selectedCategory ?? '',
        'image': imageUrl,
        'imageUrl': imageUrl,
        'isPaid': _isPaid,
        'price': _isPaid ? _price : 0,
        'teacherId': user.uid,
        'teacherName': user.displayName ?? 'Unknown',
        'teacherAvatar': user.photoURL ?? '',
        'duration': '2h 10m', // placeholder
        'studentsCount': 0,
        'level': 'Beginner',
        'rating': 4.8,
        'ratingCount': 0,
        'lessons': [
          {'title': 'Introduction to Course', 'isFree': true},
          {'title': 'Core Concepts', 'isFree': true},
          {'title': 'Project & Practice', 'isFree': false},
        ],
        'enrolledUsers': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'popularity': 0,
      };

      await FirebaseFirestore.instance.collection('courses').add(courseData);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('CreateCourse error: $e');
      setState(() {
        _error = 'Failed to create course. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Widget _buildFieldBackground({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Future<void> _showSearchableCategoryPicker() async {
    String query = '';
    final filtered = List<String>.from(_categories);

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final List<String> displayed = query.isEmpty
                ? filtered
                : _categories
                      .where(
                        (c) => c.toLowerCase().contains(query.toLowerCase()),
                      )
                      .toList();

            return AlertDialog(
              title: const Text('Select category'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search categories',
                        isDense: true,
                      ),
                      onChanged: (v) => setStateSB(() => query = v),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: displayed.isEmpty
                          ? const Center(child: Text('No categories'))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: displayed.length,
                              itemBuilder: (_, i) {
                                final c = displayed[i];
                                return ListTile(
                                  title: Text(c),
                                  onTap: () => Navigator.of(ctx).pop(c),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) setState(() => _selectedCategory = result);
  }

  void _showPickImageDialog() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.of(c).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(c).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(c).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentRow({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade50,
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.fieldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.upload, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create New Course',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Course Title',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                decoration: AppWidgets.inputDecoration(
                  hint: 'e.g., Modern Dance Fundamentals',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter title' : null,
              ),
              const SizedBox(height: 14),

              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _showSearchableCategoryPicker,
                child: _buildFieldBackground(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedCategory == null
                            ? 'Select a category'
                            : _selectedCategory!,
                        style: TextStyle(
                          color: _selectedCategory == null
                              ? Colors.grey.shade600
                              : Colors.black87,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descCtrl,
                decoration: AppWidgets.inputDecoration(
                  hint: 'Describe what students will learn...',
                ),
                maxLines: 5,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter description'
                    : null,
              ),

              const SizedBox(height: 18),
              const Text(
                'Course Thumbnail',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showPickImageDialog,
                child: Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.fieldBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 1.2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _pickedFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.image_outlined,
                                size: 28,
                                color: Colors.black54,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Upload thumbnail',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Recommended: 1280x720',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          )
                        : Image.file(
                            _pickedFile!,
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                'Course Content',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _contentRow(
                icon: Icons.videocam_outlined,
                title: 'Add Video',
                subtitle: 'Upload video lessons',
                onTap: () {
                  // TODO: video upload
                },
              ),
              const SizedBox(height: 8),
              _contentRow(
                icon: Icons.insert_drive_file_outlined,
                title: 'Add Document',
                subtitle: 'Upload PDF or resources',
                onTap: () {
                  // TODO: doc upload
                },
              ),

              const SizedBox(height: 18),
              const Text(
                'Pricing',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.fieldBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_money, color: AppColors.teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paid Course',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Set a price for your course',
                            style: TextStyle(fontSize: 12),
                          ),
                          if (_isPaid) ...[
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: _price == 0
                                  ? ''
                                  : _price.toStringAsFixed(0),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Enter price in USD',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final value = double.tryParse(v) ?? 0;
                                setState(() => _price = value);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    Switch(
                      value: _isPaid,
                      onChanged: (v) {
                        setState(() {
                          _isPaid = v;
                          if (!v) _price = 0;
                        });
                      },
                      activeColor: AppColors.teal,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveCourse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
