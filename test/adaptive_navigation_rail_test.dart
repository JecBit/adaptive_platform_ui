import 'dart:convert';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:adaptive_platform_ui/src/widgets/ios26/ios26_glass_capsule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A 1x1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAA'
  'H/q842iQAAAABJRU5ErkJggg==',
);

const _destinations = [
  AdaptiveNavigationDestination(icon: 'house', label: 'Home'),
  AdaptiveNavigationDestination(icon: 'bubble.left', label: 'Chat'),
  AdaptiveNavigationDestination(icon: 'clock', label: 'History'),
];

void main() {
  group('GlassCapsuleItem picture', () {
    test('an action carries its iconImage as image bytes', () {
      final item = GlassCapsuleItem.fromAction(
        AdaptiveAppBarAction(
          iconImage: _png,
          label: 'My profile',
          onPressed: () {},
        ),
      );

      expect(item.toNativeMap()['image'], _png);
      expect(item.canShowNatively, isTrue);
    });
  });

  group('IOS26GlassCapsule labels', () {
    Widget capsule({bool showLabels = false}) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: IOS26GlassCapsule.labeledWidth,
          height: 300,
          child: IOS26GlassCapsule(
            items: const [
              GlassCapsuleItem(symbol: 'house', label: 'Home'),
              GlassCapsuleItem(symbol: 'bubble.left', label: 'Chat'),
            ],
            selectedIndex: 0,
            showLabels: showLabels,
            onTap: (_) {},
          ),
        ),
      ),
    );

    testWidgets('asks the native view to show them', (tester) async {
      await tester.pumpWidget(capsule(showLabels: true));

      final view = tester.widget<UiKitView>(find.byType(UiKitView));
      expect((view.creationParams as Map)['showLabels'], isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('are left out unless asked for', (tester) async {
      await tester.pumpWidget(capsule());

      final view = tester.widget<UiKitView>(find.byType(UiKitView));
      expect((view.creationParams as Map).containsKey('showLabels'), isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('are drawn under the icons where there is no UIKit', (
      tester,
    ) async {
      await tester.pumpWidget(capsule(showLabels: true));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
    });

    test('a labeled tab capsule is taller than an icon-only one', () {
      expect(
        IOS26GlassCapsule.labeledTabsHeight(5),
        greaterThan(IOS26GlassCapsule.tabsHeight(5)),
      );
    });
  });

  group('AdaptiveNavigationRail', () {
    Future<void> pumpRail(
      WidgetTester tester, {
      int selectedIndex = 0,
      ValueChanged<int>? onDestinationSelected,
      List<AdaptiveAppBarAction> actions = const [],
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AdaptiveNavigationRail(
                destinations: _destinations,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected ?? (_) {},
                actions: actions,
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );

    testWidgets('off iOS 26 it is a Material rail with every label', (
      tester,
    ) async {
      await pumpRail(tester, selectedIndex: 1);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 1);
      expect(rail.labelType, NavigationRailLabelType.all);
      for (final label in ['Home', 'Chat', 'History']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('reports the destination tapped', (tester) async {
      final tapped = <int>[];
      await pumpRail(tester, onDestinationSelected: tapped.add);

      await tester.tap(find.text('History'));
      await tester.pump();

      expect(tapped, [2]);
    });

    testWidgets('puts the actions under the destinations, with their count', (
      tester,
    ) async {
      var opened = 0;
      await pumpRail(
        tester,
        actions: [
          AdaptiveAppBarAction(
            iosSymbol: 'bell',
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            badgeCount: 4,
            onPressed: () => opened++,
          ),
        ],
      );

      expect(find.text('4'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('AdaptiveNavigationRail.planFor', () {
    RailPlan plan(double height, {int actions = 2}) =>
        AdaptiveNavigationRail.planFor(
          height: height,
          destinationCount: 5,
          actionCount: actions,
          showLabels: true,
        );

    test('keeps the labels and every action when they fit (an iPad)', () {
      final it = plan(900);
      expect(it.showLabels, isTrue);
      expect(it.foldActions, isFalse);
    });

    test('drops the labels before the actions', () {
      // Labeled tabs and two actions do not fit; icon-only tabs do.
      final it = plan(380);
      expect(it.showLabels, isFalse);
      expect(it.foldActions, isFalse);
    });

    test('folds the actions into one menu when even that does not fit '
        '(a phone turned sideways)', () {
      final it = plan(345);
      expect(it.showLabels, isFalse);
      expect(it.foldActions, isTrue);
    });

    test('has nothing to fold with a single action', () {
      expect(plan(200, actions: 1).foldActions, isFalse);
    });

    test('never shows labels that were not asked for', () {
      final it = AdaptiveNavigationRail.planFor(
        height: 900,
        destinationCount: 5,
        actionCount: 2,
        showLabels: false,
      );
      expect(it.showLabels, isFalse);
    });
  });
}
