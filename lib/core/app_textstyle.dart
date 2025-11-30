import 'package:flutter/material.dart';
import 'package:skill_link_app/core/app_color.dart';

class AppTextStyles {
  static const heading = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );
  static const TextStyle body = TextStyle(fontSize: 14, color: Colors.black87);
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: Colors.black54,
  );
}
