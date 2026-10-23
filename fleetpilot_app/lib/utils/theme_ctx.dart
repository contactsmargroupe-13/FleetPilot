import 'package:flutter/material.dart';

import 'design_constants.dart';

/// Accès aux couleurs DC en tenant compte du thème courant.
///
/// Les helpers `DC.body()` / `DC.title()` / `DC.mono()` figent la couleur de
/// texte du mode clair ; tout écran écrit avec eux est illisible en mode
/// sombre. Les écrans récents passent par cette extension à la place.
extension DCContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get cBg       => isDark ? DC.darkBackground   : DC.background;
  Color get cSurface  => isDark ? DC.darkSurface      : DC.surface;
  Color get cSurface2 => isDark ? DC.darkSurface2     : DC.surface2;
  Color get cSurface3 => isDark ? DC.darkSurface3     : DC.surface3;
  Color get cBorder   => isDark ? DC.darkBorder       : DC.border;

  Color get cInk      => isDark ? DC.darkTextPrimary   : DC.textPrimary;
  Color get cInk2     => isDark ? DC.darkTextSecondary : DC.textSecondary;
  Color get cInk3     => isDark ? DC.darkTextTertiary  : DC.textTertiary;

  Color get cPrimaryBg => isDark ? DC.darkPrimaryBg : DC.primaryBg;
  Color get cSuccessBg => isDark ? DC.darkSuccessBg : DC.successBg;
  Color get cWarningBg => isDark ? DC.darkWarningBg : DC.warningBg;
  Color get cErrorBg   => isDark ? DC.darkErrorBg   : DC.errorBg;

  TextStyle tBody(double s, {FontWeight w = FontWeight.w400, Color? color}) =>
      DC.body(s, weight: w, color: color ?? cInk);
  TextStyle tTitle(double s, {FontWeight w = FontWeight.w700, Color? color}) =>
      DC.title(s, weight: w, color: color ?? cInk);
  TextStyle tMono(double s, {FontWeight w = FontWeight.w500, Color? color}) =>
      DC.mono(s, weight: w, color: color ?? cInk2);
}
