// lib/core/app_widget.dart
import 'package:flutter/material.dart';
import 'app_color.dart';
import 'app_textstyle.dart';

class AppWidgets {
  /// Reusable InputDecoration
  static InputDecoration inputDecoration({
    required String hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: AppColors.teal) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.teal, width: 1.5),
      ),
      hintStyle: AppTextStyles.caption,
    );
  }

  /// Reusable input field used across the app.
  /// Returns a TextFormField so it works inside Forms and allows validation.
  static Widget inputField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType? type,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    void Function(String?)? onSaved,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type ?? TextInputType.text,
      obscureText: obscure,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      onSaved: onSaved,
      decoration: inputDecoration(hint: hint, icon: icon, suffix: suffix),
      style: AppTextStyles.body,
    );
  }
}
