import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'main.dart' as execute;

void main() {
  runApp(const ExecuteWebPreview());
}

/// Web-only preview host.
///
/// Desktop browsers render the full navigator inside a real 360×800 logical
/// phone screen. The dark bezel is outside that logical viewport and therefore
/// does not change any mobile layout metrics. Narrow/mobile browsers render the
/// same app full-screen without the desktop presentation shell.
class ExecuteWebPreview extends StatelessWidget {
  const ExecuteWebPreview({super.key});

  static const double _screenWidth = 360;
  static const double _screenHeight = 800;
  static const double _bezel = 6;
  static const double _deviceWidth = _screenWidth + _bezel * 2;
  static const double _deviceHeight = _screenHeight + _bezel * 2;
  static const double _desktopBreakpoint = 600;
  static const double _outerPadding = 24;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LifeTrace Execute',
      theme: execute.buildTheme(),
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
            availableWidth / _deviceWidth,
            availableHeight / _deviceHeight,
          ),
        );

        final phoneMediaQuery = MediaQuery.of(context).copyWith(
          size: const Size(_screenWidth, _screenHeight),
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
          viewInsets: EdgeInsets.zero,
        );

        return ColoredBox(
          color: const Color(0xFFEEF2F7),
          child: Center(
            child: SizedBox(
              width: _deviceWidth * scale,
              height: _deviceHeight * scale,
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: Container(
                  width: _deviceWidth,
                  height: _deviceHeight,
                  padding: const EdgeInsets.all(_bezel),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171A1F),
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x300F172A),
                        blurRadius: 36,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: SizedBox(
                      width: _screenWidth,
                      height: _screenHeight,
                      child: MediaQuery(
                        data: phoneMediaQuery,
                        child: navigator,
                      ),
                    ),
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
