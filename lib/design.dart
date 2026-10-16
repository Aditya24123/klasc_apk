import 'package:flutter/material.dart';

const paper = Color(0xff0c0f0e);
const panel = Color(0xff171c19);
const ink = Color(0xffedf3ed);
const muted = Color(0xff9ea9a1);
const accent = Color(0xff86efa7);
const line = Color(0xff2b342e);

ThemeData klascTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Nunito',
      scaffoldBackgroundColor: paper,
      colorScheme: const ColorScheme.dark(
          primary: accent,
          onPrimary: paper,
          surface: panel,
          onSurface: ink,
          secondary: Color(0xffbdacfa),
          error: Color(0xffffa598)),
      appBarTheme: const AppBarTheme(
          backgroundColor: paper,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 27,
              letterSpacing: 1,
              color: ink)),
      textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontFamily: 'BebasNeue', fontSize: 48, height: 1.03, color: ink),
          headlineMedium: TextStyle(
              fontFamily: 'BebasNeue', fontSize: 34, height: 1.1, color: ink),
          titleLarge: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 26,
              letterSpacing: .4,
              color: ink),
          bodyLarge: TextStyle(
              fontFamily: 'Nunito', fontSize: 16, height: 1.5, color: ink),
          bodyMedium: TextStyle(
              fontFamily: 'Nunito', fontSize: 14, height: 1.45, color: ink)),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: accent))),
      chipTheme: ChipThemeData(
          backgroundColor: panel,
          selectedColor: accent.withValues(alpha: .15),
          side: const BorderSide(color: line),
          labelStyle: const TextStyle(fontFamily: 'Nunito', color: ink),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: paper,
          indicatorColor: accent.withValues(alpha: .14),
          height: 70),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 50),
              textStyle: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: line),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
    );

class KlascMark extends StatelessWidget {
  final double size;
  const KlascMark({super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'KLASC logo',
      image: true,
      child: Image.asset('assets/branding/klasc-symbol.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          excludeFromSemantics: true));
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) =>
      const Row(mainAxisSize: MainAxisSize.min, children: [
        KlascMark(size: 34),
        SizedBox(width: 10),
        Text('KLASC',
            style: TextStyle(
                fontFamily: 'BebasNeue', fontSize: 30, letterSpacing: 1.5))
      ]);
}
