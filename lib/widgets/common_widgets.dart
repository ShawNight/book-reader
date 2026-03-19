import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppSpacing.iconSizeXl,
              color: AppColors.grey,
            ),
            AppSpacing.verticalGapLg,
            Text(
              title,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              AppSpacing.verticalGapSm,
              Text(
                subtitle!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              AppSpacing.verticalGapLg,
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            AppSpacing.verticalGapMd,
            Text(
              message!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: message,
      action: onRetry != null
          ? ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            )
          : null,
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool outlined;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    this.outlined = false,
  });

  factory StatusBadge.read({bool outlined = false}) => StatusBadge(
        text: '已读',
        color: AppColors.success,
        outlined: outlined,
      );

  factory StatusBadge.unread({bool outlined = false}) => StatusBadge(
        text: '未读',
        color: AppColors.grey,
        outlined: outlined,
      );

  factory StatusBadge.downloaded({bool outlined = false}) => StatusBadge(
        text: '已缓存',
        color: AppColors.success,
        outlined: outlined,
      );

  factory StatusBadge.downloading({bool outlined = false}) => StatusBadge(
        text: '下载中',
        color: AppColors.info,
        outlined: outlined,
      );

  factory StatusBadge.failed({bool outlined = false}) => StatusBadge(
        text: '失败',
        color: AppColors.error,
        outlined: outlined,
      );

  factory StatusBadge.valid({bool outlined = false}) => StatusBadge(
        text: '有效',
        color: AppColors.success,
        outlined: outlined,
      );

  factory StatusBadge.invalid({bool outlined = false}) => StatusBadge(
        text: '无效',
        color: AppColors.error,
        outlined: outlined,
      );

  factory StatusBadge.pending({bool outlined = false}) => StatusBadge(
        text: '待测试',
        color: AppColors.grey,
        outlined: outlined,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: outlined ? Border.all(color: color, width: 1) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final effectiveColor = isEnabled ? (color ?? AppColors.primary) : AppColors.grey;

    return TextButton(
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: effectiveColor),
          AppSpacing.verticalGapXs,
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

class BottomActionBar extends StatelessWidget {
  final List<Widget> actions;
  final Widget? progress;

  const BottomActionBar({
    super.key,
    required this.actions,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.horizontalLg + const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: progress ?? Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: actions,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ListItemCard extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ListItemCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: AppSpacing.horizontalLg + const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppSpacing.cardBorderRadius,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                AppSpacing.horizontalGapMd,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle(
                      style: AppTextStyles.subtitle,
                      child: title,
                    ),
                    if (subtitle != null) ...[
                      AppSpacing.verticalGapXs,
                      DefaultTextStyle(
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                AppSpacing.horizontalGapSm,
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData? icon;

  const StatCard({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (icon != null)
          Icon(icon, color: color, size: AppSpacing.iconSizeMd),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class ProgressCard extends StatelessWidget {
  final String title;
  final double progress;
  final String? subtitle;
  final VoidCallback? onCancel;

  const ProgressCard({
    super.key,
    required this.title,
    required this.progress,
    this.subtitle,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.subtitle),
              if (onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  child: const Text('取消'),
                ),
            ],
          ),
          AppSpacing.verticalGapSm,
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          if (subtitle != null) ...[
            AppSpacing.verticalGapXs,
            Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
