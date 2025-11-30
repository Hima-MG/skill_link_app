// lib/screens/posts/create_post.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skill_link_app/core/app_color.dart';

class CreatePost extends StatefulWidget {
  const CreatePost({super.key});
  @override
  State<CreatePost> createState() => _CreatePostState();
}

class _CreatePostState extends State<CreatePost> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _captionCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _pickedFile;
  bool _loading = false;
  String? _error;

  // CONFIG: set these to your Cloudinary details (unsigned preset)
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
          folder: 'skilllink_posts',
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

  Future<void> _savePost() async {
    if (_captionCtrl.text.trim().isEmpty && _pickedFile == null) {
      setState(() {
        _error = 'Add a caption or an image to share a post.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');

      String mediaUrl = '';
      String thumbUrl = '';

      if (_pickedFile != null) {
        final url = await _uploadToCloudinary(_pickedFile!);
        if (url == null) throw Exception('Image upload failed');
        mediaUrl = url;
        thumbUrl = url; // use same as media
      }

      final docData = {
        'title': '',
        'description': _captionCtrl.text.trim(),
        'category': '',
        'media': mediaUrl,
        'thumb': thumbUrl,
        'isPaid': false,
        'authorId': user.uid,
        'authorName': user.displayName ?? 'Unknown',
        'authorAvatar': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('posts').add(docData);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('CreatePost error: $e');
      setState(() {
        _error = 'Failed to share post. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('New Post', style: TextStyle(color: Colors.black87)),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _loading ? null : _savePost,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        user?.photoURL != null && user!.photoURL!.isNotEmpty
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                        ? Text(
                            user?.displayName?.substring(0, 1).toUpperCase() ??
                                '?',
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _captionCtrl,
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Write a caption...',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showPickImageDialog,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 1.0),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _pickedFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 36,
                                  color: Colors.black54,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add photo or video',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap to choose from gallery or camera',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            )
                          : Image.file(_pickedFile!, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
