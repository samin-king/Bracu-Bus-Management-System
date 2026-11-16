import 'package:flutter/material.dart';

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff12386b)),
  scaffoldBackgroundColor: const Color(0xfff2f5fa),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
  ),
);
