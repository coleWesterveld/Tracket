import 'package:flutter_test/flutter_test.dart';
import 'package:firstapp/providers_and_settings/ui_state_provider.dart';

void main() {
  group('UiStateProvider page index', () {
    test('moving to a different tab notifies', () {
      final uiState = UiStateProvider();
      var notifications = 0;
      uiState.addListener(() => notifications++);

      uiState.currentPageIndex = UiStateProvider.analyticsPageIndex;

      expect(uiState.currentPageIndex, UiStateProvider.analyticsPageIndex);
      expect(notifications, greaterThan(0));
    });

    test('re-tapping the tab you are on does nothing', () {
      final uiState = UiStateProvider();
      uiState.currentPageIndex = UiStateProvider.analyticsPageIndex;

      var notifications = 0;
      uiState.addListener(() => notifications++);

      uiState.currentPageIndex = UiStateProvider.analyticsPageIndex;
      uiState.currentPageIndex = UiStateProvider.analyticsPageIndex;
      uiState.currentPageIndex = UiStateProvider.analyticsPageIndex;

      expect(uiState.currentPageIndex, UiStateProvider.analyticsPageIndex);
      expect(notifications, 0,
          reason: 'every notification refetches the goals on the analytics page');
    });

    test('a repeat tap leaves the appbar config alone', () {
      final uiState = UiStateProvider();
      uiState.currentPageIndex = UiStateProvider.analyticsPageIndex;
      uiState.setAppBarConfig(showBackButton: true, onPressed: () {});

      uiState.currentPageIndex = UiStateProvider.analyticsPageIndex;

      // The chart view owns the back button, and main.dart backs out of the
      // chart itself before setting the index. The setter must not fight it.
      expect(uiState.showAppBarBackButton, isTrue);
    });

    test('leaving a tab clears the appbar config', () {
      final uiState = UiStateProvider();
      uiState.currentPageIndex = UiStateProvider.analyticsPageIndex;
      uiState.setAppBarConfig(showBackButton: true, onPressed: () {});

      uiState.currentPageIndex = 0;

      expect(uiState.showAppBarBackButton, isFalse);
    });
  });
}
