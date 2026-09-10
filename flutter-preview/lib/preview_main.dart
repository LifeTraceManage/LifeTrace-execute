import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'main.dart' as execute;

void main() {
  runApp(const ExecuteWebPreview());
}

/// Web-only preview host.
///
/// - Desktop browsers: always render the whole app navigator inside a fixed
///   360×800 mobile viewport, so every pushed route keeps phone dimensions.
/// - Narrow/mobile browsers: use the normal full-screen mobile layout.
class ExecuteWebPreview extends StatelessWidget {
  const ExecuteWebPreview({super.key});

  static const double _phoneWidth = 360;
  static const double _phoneHeight = 800;
  static const double _desktopBreakpoint = 600;
  static const double _outerPadding = 24;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LifeTrace Execute',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: execute.C.bg,
        colorScheme: const ColorScheme.light(
          primary: execute.C.p,
          surface: execute.C.surface,
          onSurface: execute.C.ink,
          outline: execute.C.border,
          error: execute.C.red,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(fontSize: 13),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: execute.C.soft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          height: 72,
          backgroundColor: execute.C.surface,
          indicatorColor: execute.C.ps,
        ),
      ),
      builder: (context, child) {
        final navigator = child ?? const SizedBox.shrink();
        final viewport = MediaQuery.sizeOf(context);

        if (viewport.width < _desktopBreakpoint) {
          return navigator;
        }

        final availableWidth = math.max(
          1.0,
          viewport.width - _outerPadding * 2,
        );
        final availableHeight = math.max(
          1.0,
          viewport.height - _outerPadding * 2,
        );
        final scale = math.min(
          1.0,
          math.min(
            availableWidth / _phoneWidth,
            availableHeight / _phoneHeight,
          ),
        );

        final phoneMediaQuery = MediaQuery.of(context).copyWith(
          size: const Size(_phoneWidth, _phoneHeight),
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
          viewInsets: EdgeInsets.zero,
        );

        return ColoredBox(
          color: const Color(0xFFEEF2F7),
          child: Center(
            child: SizedBox(
              width: _phoneWidth * scale,
              height: _phoneHeight * scale,
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: Container(
                  width: _phoneWidth,
                  height: _phoneHeight,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFFD8DEE8)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260F172A),
                        blurRadius: 36,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: MediaQuery(
                    data: phoneMediaQuery,
                    child: navigator,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      home: const execute.Shell(),
    );
  }
}
