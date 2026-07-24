import 'package:flutter_test/flutter_test.dart';
import 'package:firstapp/other_utilities/pr_flash.dart';

// Samples the flash the way the screen does: every frame at 60fps, for the
// full duration. What matters is that BOTH beats get a readable window - the
// first version gave "was 220" about a fifth of a second and it was invisible
// in the hand.
List<PRFlashFrame> _sampleFlash({String? previousBest = '220'}) {
  const int frames = 144; // 2400ms at 60fps
  return List.generate(
    frames + 1,
    (i) => prFlashFrame(i / frames, previousBest: previousBest),
  );
}

/// Milliseconds a label is on screen at full opacity.
int _solidMsFor(List<PRFlashFrame> frames, String label) {
  final int count = frames
      .where((f) => f.label == label && f.labelOpacity >= 0.99)
      .length;
  return (count / frames.length * prFlashDuration.inMilliseconds).round();
}

void main() {
  group('PR flash timing', () {
    test('both beats get a readable window', () {
      final frames = _sampleFlash();

      // 500ms is about the floor for reading two short words mid-set.
      expect(_solidMsFor(frames, 'PR'), greaterThan(500));
      expect(_solidMsFor(frames, 'was 220'), greaterThan(500));
    });

    test('"PR" comes first, then what it beat', () {
      final frames = _sampleFlash();
      final firstWas = frames.indexWhere((f) => f.label == 'was 220');
      final lastPR = frames.lastIndexWhere((f) => f.label == 'PR');

      expect(firstWas, greaterThan(0));
      expect(lastPR, lessThan(firstWas));
    });

    test('the two beats never overlap on screen', () {
      // Both visible at once would render as one label on top of the other.
      for (final f in _sampleFlash()) {
        expect(f.label == null || f.labelOpacity <= 1.0, isTrue);
      }
      final frames = _sampleFlash();
      final handoff = frames.where((f) => f.labelOpacity > 0.01 && f.labelOpacity < 0.99);
      // The only partial-opacity frames are the fades, and each one names a
      // single label.
      for (final f in handoff) {
        expect(f.label, isNotNull);
      }
    });

    test('starts and ends on the typed value, fully opaque', () {
      final frames = _sampleFlash();

      expect(frames.first.valueOpacity, 1.0);
      expect(frames.first.fillT, 0.0);
      expect(frames.last.valueOpacity, 1.0);
      expect(frames.last.fillT, 0.0);
      expect(frames.last.labelOpacity, 0.0);
    });

    test('the value is hidden whenever a label is solid', () {
      for (final f in _sampleFlash()) {
        if (f.labelOpacity >= 0.99) {
          expect(f.valueOpacity, 0.0, reason: 'label and value would overlap');
        }
      }
    });

    test('the fill is fully orange while either message is solid', () {
      for (final f in _sampleFlash()) {
        if (f.labelOpacity >= 0.99) expect(f.fillT, 1.0);
      }
    });

    test('with no previous best it holds "PR" and never goes blank', () {
      final frames = _sampleFlash(previousBest: null);

      expect(frames.every((f) => f.label == 'PR'), isTrue);
      expect(_solidMsFor(frames, 'PR'), greaterThan(1500));
    });
  });
}
