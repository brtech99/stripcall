import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Adaptive text field that uses Material on Android/web and Cupertino on iOS.
///
/// Usage:
/// ```dart
/// AppTextField(
///   controller: _emailController,
///   label: 'Email',
///   keyboardType: TextInputType.emailAddress,
///   validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
/// )
/// ```
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

    // Add Semantics identifier for native accessibility (Maestro, Appium, etc.)
    // Check fieldKey first, then fall back to the widget's own key
    final effectiveKey = fieldKey ?? key;
    final keyId = effectiveKey is ValueKey<String>
        ? (effectiveKey as ValueKey<String>).value
        : null;
    if (keyId != null) {
      return Semantics(identifier: keyId, child: field);
    }

    return field;
  }

  Widget _buildCupertinoTextField(BuildContext context) {
    // For Cupertino, we need to wrap in a Column to show label and error
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTypography.formLabel(context)),
          AppSpacing.verticalXs,
        ],
        CupertinoTextField(
          key: fieldKey,
          controller: controller,
          placeholder: hint,
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
              ? Padding(padding: const EdgeInsets.only(left: 8), child: prefix)
              : null,
          suffix: (suffix ?? suffixIcon) != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: suffix ?? suffixIcon,
                )
              : null,
          readOnly: readOnly,
          focusNode: focusNode,
          padding: AppSpacing.formFieldPadding,
          decoration: BoxDecoration(
            border: Border.all(
              color: errorText != null
                  ? CupertinoColors.destructiveRed
                  : CupertinoColors.systemGrey4,
            ),
            borderRadius: AppSpacing.borderRadiusMd,
          ),
        ),
        if (errorText != null) ...[
          AppSpacing.verticalXs,
          Text(errorText!, style: AppTypography.errorText(context)),
        ],
      ],
    );
  }

  Widget _buildMaterialTextField(BuildContext context) {
    // Use TextFormField if validator is provided, otherwise TextField
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
    );
  }
}
