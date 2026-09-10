import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'main.dart' as execute;

void main() {
  runApp(const ExecuteWebPreview());
}

/// Desktop browsers render the mobile prototype inside a fixed 360×800
/// device viewport. Narrow/mobile browsers keep the normal full-screen app.
class ExecuteWebPreview extends StatelessWidget {
  const ExecuteWebPreview({super.key});

  static const double _phoneWidth = 360;
  static const double _phoneHeight = 800;
  static const double _desktopBreakpoint = 600;
  static const double _outerPadding = 24;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _desktopBreakpoint) {
          return const execute.LifeTracePreviewApp();
        }

        final availableWidth = math.max(1.0, constraints.maxWidth - _outerPadding * 2);
        final availableHeight = math.max(1.0, constraints.maxHeight - _outerPadding * 2);
        final scale = math.min(
          1.0,
          math.min(availableWidth / _phoneWidth, availableHeight / _phoneHeight),
        );

        return ColoredBox(
          color: const Color(0xFFEEF2F7),
          child: Center(
            child: SizedBox(
              width: _phoneWidth * scale,
              height: _phoneHeight * scale,
              child: FittedBox(
                fit: BoxFit.fill,
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
                  child: const execute.LifeTracePreviewApp(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
