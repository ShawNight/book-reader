import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: AppColors.lightColorScheme,
    scaffoldBackgroundColor: AppColors.scaffoldBackground,
    appBarTheme: _appBarTheme(Brightness.light),
    cardTheme: _cardTheme,
    listTileTheme: _listTileTheme,
    dividerTheme: _dividerTheme,
    inputDecorationTheme: _inputDecorationTheme,
    elevatedButtonTheme: _elevatedButtonTheme,
    textButtonTheme: _textButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    floatingActionButtonTheme: _fabTheme,
    chipTheme: _chipTheme,
    snackBarTheme: _snackBarTheme,
    dialogTheme: _dialogTheme,
    bottomNavigationBarTheme: _bottomNavTheme,
    navigationBarTheme: _navigationBarTheme,
    progressIndicatorTheme: _progressIndicatorTheme,
    checkboxTheme: _checkboxTheme,
    iconTheme: const IconThemeData(
      color: AppColors.textSecondary,
      size: AppSpacing.iconSizeMd,
    ),
    textTheme: _textTheme,
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: AppColors.darkColorScheme,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: _appBarTheme(Brightness.dark),
    cardTheme: _cardTheme.copyWith(
      color: const Color(0xFF1E1E1E),
    ),
    listTileTheme: _listTileTheme.copyWith(
      contentPadding: AppSpacing.listItemPadding,
    ),
    dividerTheme: _dividerTheme.copyWith(
      color: const Color(0xFF424242),
    ),
    inputDecorationTheme: _inputDecorationTheme,
    elevatedButtonTheme: _elevatedButtonTheme,
    textButtonTheme: _textButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    floatingActionButtonTheme: _fabTheme,
    chipTheme: _chipTheme,
    snackBarTheme: _snackBarTheme,
    dialogTheme: _dialogTheme.copyWith(
      backgroundColor: const Color(0xFF2D2D2D),
    ),
    bottomNavigationBarTheme: _bottomNavTheme.copyWith(
      backgroundColor: const Color(0xFF1E1E1E),
    ),
    navigationBarTheme: _navigationBarTheme.copyWith(
      backgroundColor: const Color(0xFF1E1E1E),
    ),
    progressIndicatorTheme: _progressIndicatorTheme,
    checkboxTheme: _checkboxTheme,
    iconTheme: const IconThemeData(
      color: Colors.grey,
      size: AppSpacing.iconSizeMd,
    ),
    textTheme: _textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
  );

  static AppBarTheme _appBarTheme(Brightness brightness) => AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 1,
    centerTitle: true,
    backgroundColor: brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF1E1E1E),
    foregroundColor: brightness == Brightness.light
        ? AppColors.textPrimary
        : Colors.white,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: AppTextStyles.title.copyWith(
      color: brightness == Brightness.light
          ? AppColors.textPrimary
          : Colors.white,
    ),
    iconTheme: IconThemeData(
      color: brightness == Brightness.light
          ? AppColors.textPrimary
          : Colors.white,
    ),
  );

  static CardTheme get _cardTheme => CardTheme(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppSpacing.cardBorderRadius,
    ),
    color: AppColors.cardBackground,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
  );

  static ListTileThemeData get _listTileTheme => ListTileThemeData(
    contentPadding: AppSpacing.listItemPadding,
    minVerticalPadding: AppSpacing.sm,
    horizontalTitleGap: AppSpacing.md,
    minLeadingWidth: AppSpacing.coverWidth + AppSpacing.md,
    style: ListTileStyle.list,
    titleTextStyle: AppTextStyles.subtitle.copyWith(
      color: AppColors.textPrimary,
    ),
    subtitleTextStyle: AppTextStyles.bodySmall.copyWith(
      color: AppColors.textSecondary,
    ),
  );

  static DividerThemeData get _dividerTheme => const DividerThemeData(
    thickness: AppSpacing.dividerThickness,
    color: AppColors.divider,
    space: 1,
  );

  static InputDecorationTheme get _inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.greyLight,
    contentPadding: AppSpacing.paddingMd,
    border: OutlineInputBorder(
      borderRadius: AppSpacing.inputBorderRadius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppSpacing.inputBorderRadius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppSpacing.inputBorderRadius,
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppSpacing.inputBorderRadius,
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    ),
    hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
    labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
  );

  static ElevatedButtonThemeData get _elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: AppSpacing.paddingMd,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonBorderRadius,
          ),
          textStyle: AppTextStyles.button,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      );

  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: AppSpacing.paddingMd,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.buttonBorderRadius,
      ),
      textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
    ),
  );

  static OutlinedButtonThemeData get _outlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: AppSpacing.paddingMd,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonBorderRadius,
          ),
          side: const BorderSide(color: AppColors.primary),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
        ),
      );

  static FloatingActionButtonThemeData get _fabTheme =>
      const FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      );

  static ChipThemeData get _chipTheme => ChipThemeData(
    backgroundColor: AppColors.greyLight,
    selectedColor: AppColors.primaryLight.withOpacity(0.2),
    padding: AppSpacing.paddingSm,
    labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
    shape: RoundedRectangleBorder(
      borderRadius: AppSpacing.chipBorderRadius,
    ),
    side: BorderSide.none,
  );

  static SnackBarThemeData get _snackBarTheme => SnackBarThemeData(
    backgroundColor: const Color(0xFF323232),
    contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: AppSpacing.buttonBorderRadius,
    ),
  );

  static DialogTheme get _dialogTheme => DialogTheme(
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: AppSpacing.cardBorderRadius,
    ),
    titleTextStyle: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
    contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
  );

  static BottomNavigationBarThemeData get _bottomNavTheme =>
      const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: AppTextStyles.caption,
        unselectedLabelStyle: AppTextStyles.caption,
      );

  static NavigationBarThemeData get _navigationBarTheme =>
      NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTextStyles.caption.copyWith(color: AppColors.textSecondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return const IconThemeData(color: AppColors.textSecondary);
        }),
      );

  static ProgressIndicatorThemeData get _progressIndicatorTheme =>
      const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.greyLight,
        circularTrackColor: AppColors.greyLight,
      );

  static CheckboxThemeData get _checkboxTheme => CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary;
      }
      return Colors.transparent;
    }),
    checkColor: WidgetStateProperty.all(Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
    side: const BorderSide(color: AppColors.grey, width: 2),
  );

  static TextTheme get _textTheme => TextTheme(
    displayLarge: AppTextStyles.headline1.copyWith(color: AppColors.textPrimary),
    displayMedium: AppTextStyles.headline2.copyWith(color: AppColors.textPrimary),
    displaySmall: AppTextStyles.headline3.copyWith(color: AppColors.textPrimary),
    headlineLarge: AppTextStyles.headline1.copyWith(color: AppColors.textPrimary),
    headlineMedium: AppTextStyles.headline2.copyWith(color: AppColors.textPrimary),
    headlineSmall: AppTextStyles.headline3.copyWith(color: AppColors.textPrimary),
    titleLarge: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
    titleMedium: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary),
    titleSmall: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
    bodyLarge: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
    bodyMedium: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
    bodySmall: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    labelLarge: AppTextStyles.button.copyWith(color: AppColors.textPrimary),
    labelMedium: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    labelSmall: AppTextStyles.overline.copyWith(color: AppColors.textHint),
  );
}
