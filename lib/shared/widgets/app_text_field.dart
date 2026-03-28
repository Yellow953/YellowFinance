import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_text_styles.dart';

/// Styled text input field.
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final void Function(String)? onChanged;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.prefixText,
    this.inputFormatters,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      maxLines: obscureText ? 1 : maxLines,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      enabled: enabled,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
        prefixText: prefixText,
        prefixStyle: AppTextStyles.bodyLarge,
      ),
    );
  }
}
