import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Book surfaces and ink, scoped to the chat and its dialogs.
class ReadingPalette {
  const ReadingPalette(this.dark);
  factory ReadingPalette.of(BuildContext context) =>
      ReadingPalette(Theme.of(context).brightness == Brightness.dark);
  final bool dark;
  Color get canvas => dark ? const Color(0xFF101C23) : const Color(0xFFEDE7DA);
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
