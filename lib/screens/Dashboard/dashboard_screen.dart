// lib/screens/Dashboard/dashboard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/core/app_textstyle.dart';
import 'package:skill_link_app/screens/Dashboard/both.dart';
import 'package:skill_link_app/screens/Dashboard/learner_dashboard.dart';
import 'package:skill_link_app/screens/Dashboard/teacher_dashboard.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Safe fallback if user somehow reaches here without being signed in
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          backgroundColor: AppColors.fieldBg,
        ),
        body: Center(
          child: Text(
            'Please log in to view your dashboard.',
            style: AppTextStyles.body,
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Dashboard'),
              backgroundColor: AppColors.teal,
            ),
            body: Center(
              child: Text(
                'Failed to load dashboard',
                style: AppTextStyles.body,
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Fallback if user doc not found
          return Scaffold(
            appBar: AppBar(
              title: const Text('Dashboard'),
              backgroundColor: AppColors.teal,
            ),
            body: Center(
              child: Text('No user data found', style: AppTextStyles.body),
            ),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final intent = (data['intent'] ?? 'Learn') as String;

        // Route to appropriate dashboard based on intent
        if (intent == 'Teach') {
          return TeacherDashboard(userData: data);
        } else if (intent == 'Both') {
          return BothDashboard(learnerData: data, teacherData: data);
        } else {
          // default to learner
          return LearnerDashboard(userData: data);
        }
      },
    );
  }
}
