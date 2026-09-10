import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'main.dart' as execute;

void main() => runApp(const ExecuteWebPreview());

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
      theme: execute.buildTheme(),
      builder: (context, child) {
        final navigator = child ?? const SizedBox.shrink();
        final viewport = MediaQuery.sizeOf(context);

        if (viewport.width < _desktopBreakpoint) {
          return navigator;
        }

        final availableWidth = math.max(1.0, viewport.width - _outerPadding * 2);
        final availableHeight = math.max(1.0, viewport.height - _outerPadding * 2);
        final scale = math.min(
          1.0,
          math.min(availableWidth / _phoneWidth, availableHeight / _phoneHeight),
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: const Color(0xFF111827), width: 7),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260F172A),
                        blurRadius: 36,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(27),
                    child: SizedBox(
                      width: _phoneWidth,
                      height: _phoneHeight,
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
      home: const execute.Shell(simulateSystemChrome: true),
    );
  }
}
