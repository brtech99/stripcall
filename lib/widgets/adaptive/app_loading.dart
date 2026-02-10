import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Adaptive loading indicator.
///
/// Uses CircularProgressIndicator on Android/web and
/// CupertinoActivityIndicator on iOS.
///
/// Usage:
/// ```dart
/// AppLoadingIndicator()
/// AppLoadingIndicator.small()
/// AppLoadingIndicator.large()
/// ```
class AppLoadingIndicator extends StatelessWidget {
  final double? size;
  final Color? color;
  final double strokeWidth;

  const AppLoadingIndicator({
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 2.0,
  });

  /// Small loading indicator (16px)
  const AppLoadingIndicator.small({super.key, this.color})
    : size = 16.0,
      strokeWidth = 2.0;

  /// Medium loading indicator (24px, default)
  const AppLoadingIndicator.medium({super.key, this.color})
    : size = 24.0,
      strokeWidth = 2.0;

  /// Large loading indicator (48px)
  const AppLoadingIndicator.large({super.key, this.color})
    : size = 48.0,
      strokeWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return CupertinoActivityIndicator(radius: (size ?? 20) / 2, color: color);
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: strokeWidth, color: color),
    );
  }
}

/// A centered loading indicator, useful for full-screen loading states.
class AppLoadingOverlay extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;

  const AppLoadingOverlay({super.key, this.message, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color:
          backgroundColor ?? AppColors.surface(context).withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLoadingIndicator.large(),
            if (message != null) ...[
              AppSpacing.verticalMd,
              Text(message!, style: AppTypography.bodyMedium(context)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A widget that shows a loading indicator while data is being loaded,
/// then shows content or an error state.
class AppAsyncContent<T> extends StatelessWidget {
  final AsyncSnapshot<T>? snapshot;
  final bool isLoading;
  final String? error;
  final T? data;
  final Widget Function(T data) builder;
  final Widget Function(String error)? errorBuilder;
  final Widget? loadingWidget;
  final String? loadingMessage;
  final VoidCallback? onRetry;

  const AppAsyncContent({
    super.key,
    this.snapshot,
    this.isLoading = false,
    this.error,
    this.data,
    required this.builder,
    this.errorBuilder,
    this.loadingWidget,
    this.loadingMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Determine state from snapshot or explicit values
    final effectiveIsLoading =
        snapshot?.connectionState == ConnectionState.waiting || isLoading;
    final effectiveError = snapshot?.error?.toString() ?? error;
    final effectiveData = snapshot?.data ?? data;

    if (effectiveIsLoading) {
      return loadingWidget ??
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLoadingIndicator(),
                if (loadingMessage != null) ...[
                  AppSpacing.verticalMd,
                  Text(
                    loadingMessage!,
                    style: AppTypography.bodyMedium(context),
                  ),
                ],
              ],
            ),
          );
    }

    if (effectiveError != null) {
      if (errorBuilder != null) {
        return errorBuilder!(effectiveError);
      }
      return Center(
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: AppSpacing.iconXl,
                color: AppColors.error(context),
              ),
              AppSpacing.verticalMd,
              Text(
                effectiveError,
                style: AppTypography.bodyMedium(
                  context,
                ).copyWith(color: AppColors.error(context)),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                AppSpacing.verticalMd,
                ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      );
    }

    if (effectiveData != null) {
      return builder(effectiveData as T);
    }

    // No data yet and not loading - show nothing or placeholder
    return const SizedBox.shrink();
  }
}

/// Empty state widget for when there's no content to display.
class AppEmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: AppSpacing.iconXl,
                color: AppColors.textSecondary(context),
              ),
            if (icon != null) AppSpacing.verticalMd,
            Text(
              title,
              style: AppTypography.titleMedium(context),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              AppSpacing.verticalSm,
              Text(
                subtitle!,
                style: AppTypography.bodyMedium(
                  context,
                ).copyWith(color: AppColors.textSecondary(context)),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[AppSpacing.verticalLg, action!],
          ],
        ),
      ),
    );
  }
}
