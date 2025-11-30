// lib/screens/Dashboard/both.dart
import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';
import 'package:skill_link_app/screens/Dashboard/learner_dashboard.dart';
import 'package:skill_link_app/screens/Dashboard/teacher_dashboard.dart';

class BothDashboard extends StatelessWidget {
  final Map<String, dynamic> learnerData;
  final Map<String, dynamic> teacherData;

  const BothDashboard({
    super.key,
    required this.learnerData,
    required this.teacherData,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'SkillLink',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              ),
              SizedBox(height: 2),
              Text(
                'Learn and teach skills',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F7),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const TabBar(
                  indicatorWeight: BorderSide.strokeAlignCenter,
                  indicator: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black54,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(fontSize: 13),
                  tabs: [
                    Tab(
                      icon: Icon(Icons.menu_book_outlined, size: 20),
                      text: 'Learn',
                    ),
                    Tab(
                      icon: Icon(Icons.school_outlined, size: 20),
                      text: 'Teach',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            LearnerDashboard(userData: learnerData),
            TeacherDashboard(userData: teacherData),
          ],
        ),
      ),
    );
  }
}
