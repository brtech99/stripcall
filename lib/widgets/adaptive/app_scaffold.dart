import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Adaptive scaffold that uses Material Scaffold on Android/web
/// and CupertinoPageScaffold on iOS.
///
/// Usage:
/// ```dart
/// AppScaffold(
///   title: 'My Page',
///   body: MyContent(),
///   actions: [
///     AppIconButton(onPressed: _save, icon: Icon(Icons.save)),
///   ],
/// )
/// ```
class AppScaffold extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  const AppScaffold({
    super.key,
    this.title,
    this.titleWidget,
    required this.body,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return _buildCupertinoScaffold(context);
    }

    return _buildMaterialScaffold(context);
  }

  Widget _buildCupertinoScaffold(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor ?? AppColors.surface(context),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      navigationBar: CupertinoNavigationBar(
        middle: titleWidget ?? (title != null ? Text(title!) : null),
        leading:
            leading ??
            (showBackButton && canPop
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed:
                        onBackPressed ?? () => Navigator.of(context).pop(),
                    child: const Icon(CupertinoIcons.back),
                  )
                : null),
        trailing: actions != null && actions!.isNotEmpty
            ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
            : null,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            body,
            if (floatingActionButton != null)
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: floatingActionButton!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialScaffold(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        title: titleWidget ?? (title != null ? Text(title!) : null),
        leading:
            leading ??
            (showBackButton && canPop
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed:
                        onBackPressed ?? () => Navigator.of(context).pop(),
                  )
                : null),
        automaticallyImplyLeading: showBackButton,
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Adaptive app bar for use within existing Scaffolds or for customization.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final double? elevation;
  final Color? backgroundColor;

  const AppAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.onBackPressed,
    this.elevation,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return _buildCupertinoNavBar(context);
    }

    return _buildMaterialAppBar(context);
  }

  Widget _buildCupertinoNavBar(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return CupertinoNavigationBar(
      middle: titleWidget ?? (title != null ? Text(title!) : null),
      leading:
          leading ??
          (showBackButton && canPop
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                  child: const Icon(CupertinoIcons.back),
                )
              : null),
      trailing: actions != null && actions!.isNotEmpty
          ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
          : null,
      backgroundColor: backgroundColor,
    );
  }

  Widget _buildMaterialAppBar(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return AppBar(
      title: titleWidget ?? (title != null ? Text(title!) : null),
      leading:
          leading ??
          (showBackButton && canPop
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                )
              : null),
      automaticallyImplyLeading: showBackButton,
      actions: actions,
      elevation: elevation,
      backgroundColor: backgroundColor,
    );
  }
}
