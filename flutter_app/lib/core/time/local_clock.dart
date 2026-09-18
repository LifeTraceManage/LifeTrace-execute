import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared local wall clock for date-sensitive UI and repository projections.
///
/// The minute cadence is sufficient for Today/date rollover semantics while
/// avoiding a per-second rebuild of unrelated providers. Each tick calls
/// DateTime.now() again, so device timezone/clock changes are observed too.
final localMinuteClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  );
});
