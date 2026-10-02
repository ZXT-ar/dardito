import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Shared paper surfaces and ink for every site section.
class SitePalette {
  const SitePalette(this.dark);
  factory SitePalette.of(BuildContext context) =>
      SitePalette(Theme.of(context).brightness == Brightness.dark);
  final bool dark;
  Color get canvas => dark ? const Color(0xFF101C23) : AppColors.heroPaper;
  Color get cream => canvas;
  Color get heroPaper => canvas;
  Color get navy => canvas;
  Color get paper => dark ? const Color(0xFF202C32) : AppColors.paper;
  Color get plate => dark ? const Color(0xFF29373C) : const Color(0xFFFFFDF8);
  Color get ink => dark ? const Color(0xFFF0E6D2) : AppColors.ink;
  Color get muted => dark ? const Color(0xFFBDB7A9) : AppColors.muted;
  Color get line => dark ? const Color(0xFF52605F) : AppColors.line;
  Color get inset => dark ? const Color(0xFF29373C) : const Color(0xFFE3DCCB);
  Color get green => dark ? const Color(0xFFB9C795) : AppColors.green;
  Color get rust => dark ? const Color(0xFFE7AD7C) : AppColors.rust;
  Color get highlight =>
      dark ? const Color(0xFF51472C) : const Color(0xFFF5E8BC);
  Color get edge => dark ? const Color(0xFF46504E) : const Color(0xFFD0C4AA);
  Color get leaf => dark ? const Color(0xFF333F42) : const Color(0xFFE8DDC8);

  ThemeData theme(ThemeData base) => base.copyWith(
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: base.colorScheme.copyWith(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: ink,
      onPrimary: canvas,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: line,
    ),
    scaffoldBackgroundColor: canvas,
    cardTheme: base.cardTheme.copyWith(
      color: paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: line),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: paper),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: paper),
    dividerColor: line,
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: inset,
      labelStyle: TextStyle(color: ink),
      side: BorderSide(color: line),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: canvas,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: BorderSide(color: line),
      ),
    ),
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    iconTheme: IconThemeData(color: muted),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ink),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: paper,
      hintStyle: TextStyle(color: muted),
      counterStyle: TextStyle(color: muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: rust,
      selectionColor: rust.withValues(alpha: .3),
      selectionHandleColor: rust,
    ),
  );
}
