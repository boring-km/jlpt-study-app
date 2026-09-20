import 'package:flutter/material.dart';

/// "종이와 먹" 팔레트.
///
/// 종이(배경) · 먹(텍스트·주 버튼) · 주홍(선택·진행·강조) 세 색만 쓴다.
/// 카드는 테두리 대신 종이보다 한 톤 어두운 면으로 구분하고, 선은 리스트 안
/// 헤어라인 하나뿐이다. 다크는 같은 세 색을 뒤집는다.
class AppColors {
  // 주홍(朱) — 선택 상태, 진행률, 읽기 강조. 라이트/다크 각각 대비 맞춤.
  static const primary = Color(0xFFB5371F);
  static const primaryDark = Color(0xFFEC7A63);
  static const accent = primary;

  // 이끼 — 정답. 색만으로 의미를 전하지 않도록 항상 아이콘과 함께 쓴다.
  static const success = Color(0xFF2A6236);
  static const successDark = Color(0xFF7CBF8A);

  // 오류 텍스트. 주홍과 같은 계열이지만 더 어둡게.
  static const error = Color(0xFFA83A26);
  static const errorDark = Color(0xFFE88A78);

  // 라이트: 종이
  static const backgroundLight = Color(0xFFFAF8F3);
  static const surfaceLight = Color(0xFFFAF8F3);
  static const surfaceContainerLight = Color(0xFFF1EDE5);
  static const surfaceContainerHighLight = Color(0xFFE8E2D8);
  static const textPrimaryLight = Color(0xFF1C1917);
  static const textSecondaryLight = Color(0xFF6B655D);
  static const borderLight = Color(0xFFE3DDD2);

  // 다크: 먹
  static const backgroundDark = Color(0xFF151311);
  static const surfaceDark = Color(0xFF151311);
  static const surfaceContainerDark = Color(0xFF211E1B);
  static const surfaceContainerHighDark = Color(0xFF2C2825);
  static const textPrimaryDark = Color(0xFFEDE8E0);
  static const textSecondaryDark = Color(0xFFA39C92);
  static const borderDark = Color(0xFF2F2B27);
}

/// 4pt 그리드 간격.
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
}

/// 일본어 텍스트 전용 스타일. 한자 자형이 한국식으로 나오지 않도록
/// NotoSansJP를 먼저 쓰고, 없는 글리프(기호·숫자)는 Pretendard로 떨어진다.
/// NotoSansJP는 Regular 한 웨이트만 번들돼 있어 굵기는 크기로 대신한다.
abstract class AppText {
  static const jaFamily = 'NotoSansJP';
  static const jaFallback = ['Pretendard'];

  /// 퀴즈의 한자 — 화면의 주인공.
  static TextStyle jaHero(BuildContext context) => TextStyle(
    fontFamily: jaFamily,
    fontFamilyFallback: jaFallback,
    fontSize: 64,
    height: 1.15,
    fontWeight: FontWeight.w400,
    color: Theme.of(context).colorScheme.onSurface,
  );

  /// 플래시카드 앞면·뒷면 표제.
  static TextStyle jaDisplay(BuildContext context) => TextStyle(
    fontFamily: jaFamily,
    fontFamilyFallback: jaFallback,
    fontSize: 44,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: Theme.of(context).colorScheme.onSurface,
  );

  /// 플래시카드 뒷면 등 한 단계 작은 표제.
  static TextStyle jaHeadline(BuildContext context) => TextStyle(
    fontFamily: jaFamily,
    fontFamilyFallback: jaFallback,
    fontSize: 34,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: Theme.of(context).colorScheme.onSurface,
  );

  /// 가나 표 셀의 글자.
  static TextStyle jaKana(BuildContext context) => TextStyle(
    fontFamily: jaFamily,
    fontFamilyFallback: jaFallback,
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: Theme.of(context).colorScheme.onSurface,
  );

  /// 선택지·읽기 등 강조 라인.
  static TextStyle jaTitle(BuildContext context, {Color? color}) => TextStyle(
    fontFamily: jaFamily,
    fontFamilyFallback: jaFallback,
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );

  /// 리스트 표제(단어 타일).
  static TextStyle jaLabel(BuildContext context, {Color? color}) => TextStyle(
    fontFamily: jaFamily,
    fontFamilyFallback: jaFallback,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );

  /// 예문 등 본문 일본어.
  static TextStyle jaBody(BuildContext context, {Color? color}) => TextStyle(
    fontFamily: jaFamily,
    fontFamilyFallback: jaFallback,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );

  /// 예문 읽기 등 보조 일본어.
  static TextStyle jaCaption(BuildContext context, {Color? color}) => TextStyle(
    fontFamily: jaFamily,
    fontFamilyFallback: jaFallback,
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

/// 색 역할 접근 단축.
extension AppColorSchemeX on ColorScheme {
  /// 정답 색. 이끼. tertiary가 단일 출처다.
  Color get success => tertiary;

  /// 정답 배경 틴트.
  Color get successContainer => tertiaryContainer;
}

class AppTheme {
  static ThemeData light() => _build(
    brightness: Brightness.light,
    primary: AppColors.primary,
    error: AppColors.error,
    background: AppColors.backgroundLight,
    surfaceContainer: AppColors.surfaceContainerLight,
    surfaceContainerHigh: AppColors.surfaceContainerHighLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    border: AppColors.borderLight,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    primary: AppColors.primaryDark,
    error: AppColors.errorDark,
    background: AppColors.backgroundDark,
    surfaceContainer: AppColors.surfaceContainerDark,
    surfaceContainerHigh: AppColors.surfaceContainerHighDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    border: AppColors.borderDark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color error,
    required Color background,
    required Color surfaceContainer,
    required Color surfaceContainerHigh,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;
    // 주 버튼은 "먹" — 라이트에선 먹 위 종이 글자, 다크에선 종이 위 먹 글자.
    final inkButton = textPrimary;
    final onInkButton = background;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      // 다크의 연한 주홍 위에는 흰 글자가 3:1도 안 나온다 — 먹 글자로.
      onPrimary: isDark ? background : Colors.white,
      primaryContainer: primary.withValues(alpha: isDark ? 0.22 : 0.12),
      onPrimaryContainer: primary,
      secondary: textPrimary,
      onSecondary: background,
      secondaryContainer: surfaceContainerHigh,
      onSecondaryContainer: textPrimary,
      tertiary: isDark ? AppColors.successDark : AppColors.success,
      onTertiary: isDark ? background : Colors.white,
      tertiaryContainer: (isDark ? AppColors.successDark : AppColors.success)
          .withValues(alpha: 0.14),
      onTertiaryContainer: isDark ? AppColors.successDark : AppColors.success,
      error: error,
      onError: isDark ? background : Colors.white,
      errorContainer: error.withValues(alpha: isDark ? 0.22 : 0.12),
      onErrorContainer: error,
      surface: background,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: background,
      surfaceContainerLow: surfaceContainer,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHigh,
      surfaceDim: surfaceContainer,
      surfaceBright: background,
      outline: textSecondary,
      outlineVariant: border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: textPrimary,
      onInverseSurface: background,
      inversePrimary: primary,
      surfaceTint: Colors.transparent,
    );

    final textTheme = _textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Pretendard',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surfaceContainer,
      dividerColor: border,
      shadowColor: Colors.black,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: textPrimary, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? textPrimary
                : textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? textPrimary
                : textSecondary,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: inkButton,
          foregroundColor: onInkButton,
          disabledBackgroundColor: surfaceContainerHigh,
          disabledForegroundColor: textSecondary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: inkButton,
          foregroundColor: onInkButton,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(44, 44),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainer,
        selectedColor: primary,
        disabledColor: surfaceContainer,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        iconTheme: IconThemeData(color: primary, size: 18),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? inkButton
                : surfaceContainer,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? onInkButton
                : textPrimary,
          ),
          side: const WidgetStatePropertyAll(BorderSide.none),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        hintStyle: TextStyle(color: textSecondary, fontSize: 15),
        labelStyle: TextStyle(color: textSecondary, fontSize: 15),
        floatingLabelStyle: TextStyle(color: primary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 14,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        iconColor: textSecondary,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: background,
        showDragHandle: true,
        dragHandleColor: border,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(color: background, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceContainerHigh,
        circularTrackColor: Colors.transparent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: surfaceContainer,
        headerForegroundColor: textPrimary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
        dividerColor: border,
      ),
      splashColor: textPrimary.withValues(alpha: 0.06),
      highlightColor: textPrimary.withValues(alpha: 0.04),
    );
  }

  /// 6단계 스케일: 11 · 13 · 15 · 17 · 22 · 34.
  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
    displayLarge: TextStyle(
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: primary,
    ),
    displayMedium: TextStyle(
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: primary,
    ),
    displaySmall: TextStyle(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: primary,
    ),
    headlineLarge: TextStyle(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: primary,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: primary,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: primary,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: primary,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    titleSmall: TextStyle(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: secondary,
    ),
    bodyLarge: TextStyle(
      fontSize: 17,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: primary,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: primary,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: secondary,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w500,
      color: secondary,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: secondary,
    ),
  );
}
