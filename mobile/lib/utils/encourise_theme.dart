import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================================
// Encourise Design System v5 — Kelas Tenang
// =============================================================================

class EncouriseColors {
  EncouriseColors._();

  // Primary — jade/teal
  static const primary = Color(0xFF0F8F7B);
  static const primaryLight = Color(0xFF7EDCC8);
  static const primaryDark = Color(0xFF086657);
  static const primarySurface = Color(0xFFE5F6F1);

  // Backgrounds — daylight learning space
  static const background = Color(0xFFFFFCF6);
  static const surface = Color(0xFFFFFFFF);
  static const cardFill = Color(0xFFFFFFFF);
  static const darkHeader = Color(0xFF123B35);
  static const darkSurface = Color(0xFFF4EFE6);

  // Text
  static const textPrimary = Color(0xFF182422);
  static const textSecondary = Color(0xFF5F6F69);
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const textOnDark = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF8A9892);

  // Borders & dividers
  static const border = Color(0xFFE7E0D4);
  static const divider = Color(0xFFECE5D9);

  // Semantic
  static const success = Color(0xFF0F8F7B);
  static const successLight = Color(0xFFE5F6F1);
  static const warning = Color(0xFFEAB32C);
  static const warningLight = Color(0xFFFFF4D8);
  static const error = Color(0xFFE56E5C);
  static const errorLight = Color(0xFFFFECE8);

  // Gamification
  static const streakOrange = Color(0xFFF47B45);
  static const xpGold = Color(0xFFF6BE3B);
  static const levelPurple = Color(0xFF5A64C8);

  // Subject colors
  static const subjectPurple = Color(0xFF6570D6);
  static const subjectTeal = Color(0xFF0F8F7B);
  static const subjectPink = Color(0xFFE9789F);
  static const subjectGold = Color(0xFFEAB32C);
  static const subjectCoral = Color(0xFFE56E5C);
  static const subjectBlue = Color(0xFF3F8FCB);
  static const subjectPeach = Color(0xFFE99B62);
  static const subjectMint = Color(0xFF55BFA7);
  static const subjectRose = Color(0xFFC96582);
  static const subjectLime = Color(0xFF86B946);

  // Chat bubbles
  static const chatUser = Color(0xFFDDF5EC);
  static const chatUserEnd = Color(0xFFBEEBD9);
  static const chatBot = Color(0xFFFFFFFF);
  static const chatBotBorder = Color(0xFFE7E0D4);

  // Bottom nav
  static const navBarBg = Color(0xFFFFFFFF);
  static const navActive = Color(0xFF0F8F7B);
  static const navInactive = Color(0xFF7F8D88);

  static const List<Color> subjectColors = [
    subjectTeal,
    subjectGold,
    subjectBlue,
    subjectPurple,
    subjectCoral,
    subjectMint,
    subjectPeach,
    subjectRose,
    subjectLime,
    subjectPink,
  ];
}

class EncouriseGradients {
  EncouriseGradients._();

  static const primary = LinearGradient(
    colors: [Color(0xFF0F8F7B), Color(0xFF0B7667)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primaryVertical = LinearGradient(
    colors: [Color(0xFF13A28C), Color(0xFF0B7667)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const header = LinearGradient(
    colors: [Color(0xFFFFFCF6), Color(0xFFFFFCF6)],
  );

  static const headerAccent = LinearGradient(
    colors: [Color(0xFFE5F6F1), Color(0xFFFFFCF6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const chatBubble = LinearGradient(
    colors: [Color(0xFFDDF5EC), Color(0xFFBEEBD9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const streakBadge = LinearGradient(
    colors: [Color(0xFFF47B45), Color(0xFFF6BE3B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const successBadge = LinearGradient(
    colors: [Color(0xFF0F8F7B), Color(0xFF43C0A7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const glass = LinearGradient(
    colors: [Color(0xCCFFFFFF), Color(0x66FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class EncouriseShadows {
  EncouriseShadows._();

  static List<BoxShadow> get card => [
    BoxShadow(
      color: const Color(0xFF26453E).withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get cardHover => [
    BoxShadow(
      color: const Color(0xFF26453E).withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get button => [
    BoxShadow(
      color: EncouriseColors.primary.withValues(alpha: 0.24),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: const Color(0xFF26453E).withValues(alpha: 0.06),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get bottomNav => [
    BoxShadow(
      color: const Color(0xFF26453E).withValues(alpha: 0.10),
      blurRadius: 22,
      offset: const Offset(0, -6),
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: const Color(0xFF26453E).withValues(alpha: 0.16),
      blurRadius: 32,
      offset: const Offset(0, 16),
    ),
  ];
}

class EncouriseRadius {
  EncouriseRadius._();

  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 100;
}

class EncouriseSpacing {
  EncouriseSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class EncouriseTextStyles {
  EncouriseTextStyles._();

  static TextStyle get h1 => GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: EncouriseColors.textPrimary,
    height: 1.2,
  );

  static TextStyle get h2 => GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: EncouriseColors.textPrimary,
    height: 1.25,
  );

  static TextStyle get h3 => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: EncouriseColors.textPrimary,
    height: 1.3,
  );

  static TextStyle get bodyLg => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: EncouriseColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodyMd => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: EncouriseColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodySm => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: EncouriseColors.textSecondary,
    height: 1.4,
  );

  static TextStyle get labelLg => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: EncouriseColors.textPrimary,
  );

  static TextStyle get labelMd => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: EncouriseColors.textPrimary,
  );

  static TextStyle get labelSm => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: EncouriseColors.textSecondary,
  );

  static TextStyle get caption => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: EncouriseColors.textMuted,
    height: 1.3,
  );

  static TextStyle get h1OnDark =>
      h1.copyWith(color: EncouriseColors.textOnDark);

  static TextStyle get bodyOnDark =>
      bodyMd.copyWith(color: Colors.white.withValues(alpha: 0.86));

  static TextStyle get labelOnDark => GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: EncouriseColors.textOnDark,
  );

  static TextStyle get navLabel =>
      GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700);

  static TextStyle get chatMessage => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle get sectionTitle => GoogleFonts.plusJakartaSans(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    color: EncouriseColors.textPrimary,
  );
}

ThemeData buildEncouriseTheme() {
  final textTheme = GoogleFonts.plusJakartaSansTextTheme(
    ThemeData.light().textTheme,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    textTheme: textTheme,
    scaffoldBackgroundColor: EncouriseColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: EncouriseColors.primary,
      brightness: Brightness.light,
      primary: EncouriseColors.primary,
      onPrimary: EncouriseColors.textOnPrimary,
      surface: EncouriseColors.surface,
      onSurface: EncouriseColors.textPrimary,
      error: EncouriseColors.error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: EncouriseColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: EncouriseColors.textPrimary),
      titleTextStyle: EncouriseTextStyles.h3,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: EncouriseColors.primary,
        foregroundColor: EncouriseColors.textOnPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        ),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EncouriseColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        borderSide: const BorderSide(color: EncouriseColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        borderSide: const BorderSide(color: EncouriseColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        borderSide: const BorderSide(
          color: EncouriseColors.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: EncouriseColors.textMuted,
        fontSize: 14,
      ),
    ),
    cardTheme: CardThemeData(
      color: EncouriseColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: EncouriseColors.divider,
      thickness: 1,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: EncouriseColors.navBarBg,
      selectedItemColor: EncouriseColors.navActive,
      unselectedItemColor: EncouriseColors.navInactive,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: EncouriseTextStyles.navLabel,
      unselectedLabelStyle: EncouriseTextStyles.navLabel,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: EncouriseColors.darkHeader,
      contentTextStyle: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class EncouriseGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;

  const EncouriseGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null ? EncouriseGradients.primary : null,
          color: onPressed == null
              ? EncouriseColors.border.withValues(alpha: 0.7)
              : null,
          borderRadius: BorderRadius.circular(EncouriseRadius.lg),
          boxShadow: onPressed != null ? EncouriseShadows.button : null,
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: EncouriseColors.textOnPrimary,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: EncouriseColors.textMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EncouriseRadius.lg),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: EncouriseColors.textOnPrimary,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class EncouriseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double borderRadius;

  const EncouriseCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.gradient,
    this.borderRadius = EncouriseRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: gradient == null ? (color ?? EncouriseColors.surface) : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: gradient == null
                ? Border.all(color: EncouriseColors.border)
                : null,
            boxShadow: EncouriseShadows.card,
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = EncouriseRadius.lg,
    this.blur = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: EncouriseGradients.glass,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class BudiAvatar extends StatelessWidget {
  final double size;

  const BudiAvatar({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEAF1FF),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: EncouriseShadows.soft,
      ),
      alignment: Alignment.center,
      child: Text(
        'B',
        style: GoogleFonts.plusJakartaSans(
          color: EncouriseColors.levelPurple,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

class EncouriseStatusPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const EncouriseStatusPill({
    super.key,
    this.label = 'AI siap',
    this.icon = Icons.circle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: EncouriseColors.primarySurface,
        borderRadius: BorderRadius.circular(EncouriseRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: EncouriseColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: EncouriseColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class EncouriseSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  const EncouriseSearchBar({
    super.key,
    this.hintText = 'Search...',
    this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        border: Border.all(color: EncouriseColors.border),
        boxShadow: EncouriseShadows.soft,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: EncouriseTextStyles.bodyMd,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.plusJakartaSans(
            color: EncouriseColors.textMuted,
            fontSize: 14,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 8),
            child: Icon(
              Icons.search_rounded,
              color: EncouriseColors.textMuted,
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 46),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class EncourisePillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;

  const EncourisePillChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? EncouriseColors.primary : EncouriseColors.surface,
          borderRadius: BorderRadius.circular(EncouriseRadius.pill),
          border: Border.all(
            color: isSelected
                ? EncouriseColors.primary
                : EncouriseColors.border,
          ),
          boxShadow: isSelected ? EncouriseShadows.button : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? EncouriseColors.textOnPrimary
                    : EncouriseColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? EncouriseColors.textOnPrimary
                    : EncouriseColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EncouriseChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSend;
  final String hintText;
  final bool enabled;

  const EncouriseChatInput({
    super.key,
    required this.controller,
    this.onSend,
    this.hintText = 'Tulis jawaban...',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        borderRadius: BorderRadius.circular(EncouriseRadius.pill),
        boxShadow: EncouriseShadows.soft,
        border: Border.all(color: EncouriseColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: EncouriseTextStyles.bodyMd,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: EncouriseColors.textMuted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: EncouriseGradients.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onSend,
              icon: const Icon(
                Icons.send_rounded,
                color: EncouriseColors.textOnPrimary,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
