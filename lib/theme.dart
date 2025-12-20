import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final ColorScheme colorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFEA3546),
  onPrimary: Color(0xFFFFFDED),
  secondary: Color(0xFF799496),
  onSecondary: Color(0xFFFFFDED),
  surface: Color(0xFF171219),
  onSurface: Color(0xFFFFFDED),
  error: Color(0xFFFFFFFF),
  onError: Color(0xFFFFFFFF),
);

final ThemeData appTheme = ThemeData(
  colorScheme: colorScheme,
  useMaterial3: true,
  textTheme: TextTheme(
    headlineMedium: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 24, color: colorScheme.onSurface),
    bodyMedium: GoogleFonts.montserrat(fontSize: 16, color: colorScheme.onSurface),
  ),
);
