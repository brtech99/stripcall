import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Adaptive text field.
///
/// iOS: CupertinoTextField in grouped-row style (placeholder as label, no border
/// by default — border provided by the enclosing grouped card).
/// Material: TextFormField with outlined decoration.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final Widget? prefix;
  final Widget? suffix;
  final Widget? suffixIcon;
  final bool readOnly;
  final FocusNode? focusNode;
  final Key? fieldKey;
  final Iterable<String>? autofillHints;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.prefix,
    this.suffix,
    this.suffixIcon,
    this.readOnly = false,
    this.focusNode,
    this.fieldKey,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    Widget field;
    if (isApple) {
      field = _buildCupertinoTextField(context);
    } else {
      field = _buildMaterialTextField(context);
    }

    final effectiveKey = fieldKey ?? key;
    final keyId =
        effectiveKey is ValueKey<String> ? effectiveKey.value : null;
    if (keyId != null) {
      return Semantics(identifier: keyId, child: field);
    }

    return field;
  }

  Widget _buildCupertinoTextField(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoTextField(
          key: fieldKey,
          controller: controller,
          placeholder: hint ?? label,
          placeholderStyle: TextStyle(
            color: isDark
                ? AppColors.iosTextSecondaryDark
                : AppColors.iosTextSecondary,
            fontSize: 17,
          ),
          style: TextStyle(
            color: isDark
                ? AppColors.iosTextPrimaryDark
                : AppColors.iosTextPrimary,
            fontSize: 17,
          ),
          obscureText: obscureText,
          enabled: enabled,
          autofocus: autofocus,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onTap: onTap,
          prefix: prefix != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: prefix,
                )
              : null,
          suffix: (suffix ?? suffixIcon) != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: suffix ?? suffixIcon,
                )
              : null,
          readOnly: readOnly,
          focusNode: focusNode,
          autofillHints: autofillHints,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.iosSurfaceDark : AppColors.iosSurface,
            border: errorText != null
                ? Border.all(color: CupertinoColors.destructiveRed)
                : null,
            borderRadius: AppSpacing.borderRadiusLg,
          ),
        ),
        if (errorText != null) ...[
          AppSpacing.verticalXs,
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(errorText!, style: AppTypography.errorText(context)),
          ),
        ],
      ],
    );
  }

  Widget _buildMaterialTextField(BuildContext context) {
    if (validator != null) {
      return TextFormField(
        key: fieldKey,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          prefixIcon: prefix,
          suffixIcon: suffix ?? suffixIcon,
        ),
        obscureText: obscureText,
        enabled: enabled,
        autofocus: autofocus,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        onTap: onTap,
        validator: validator,
        readOnly: readOnly,
        focusNode: focusNode,
        autofillHints: autofillHints,
      );
    }

    return TextField(
      key: fieldKey,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: prefix,
        suffixIcon: suffix ?? suffixIcon,
      ),
      obscureText: obscureText,
      enabled: enabled,
      autofocus: autofocus,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      readOnly: readOnly,
      focusNode: focusNode,
      autofillHints: autofillHints,
    );
  }
}
