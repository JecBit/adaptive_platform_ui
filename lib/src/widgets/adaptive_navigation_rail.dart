import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import 'adaptive_app_bar_action.dart';
import 'adaptive_scaffold.dart';
import 'ios26/ios26_glass_capsule.dart';

/// How an [AdaptiveNavigationRail] fits the height it has: whether the
/// destinations keep their labels, and whether the actions fold into one
/// control that opens a menu of them.
typedef RailPlan = ({bool showLabels, bool foldActions});

/// A vertical navigation bar along the leading edge, for windows wide enough
/// to give one: an iPad, a phone turned sideways.
///
/// - **iOS 26+**: native Liquid Glass. The destinations are one glass capsule,
///   with the selected one highlighted and, by default, its label under each
///   icon; the [actions] are a second capsule at the foot. Both are the
///   capsules of the iPhone Duo bar ([IOS26GlassCapsule]), laid out by the app
///   instead of the system.
/// - **Everywhere else**: a Material [NavigationRail], with the [actions] at
///   its foot.
///
/// UIKit has no vertical tab bar outside a split view's sidebar, so this is
/// the closest native material for a rail drawn by a Flutter app.
class AdaptiveNavigationRail extends StatelessWidget {
  const AdaptiveNavigationRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.actions = const [],
    this.showLabels = true,
    this.tint,
  });

  /// The destinations, top to bottom. SF Symbol names, [IconData] and
  /// [ImageProvider]s work as icons, as in [AdaptiveBottomNavigationBar].
  final List<AdaptiveNavigationDestination> destinations;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Controls at the foot of the rail, such as notifications or the profile.
  /// They take a [AdaptiveAppBarAction.badgeCount] and an
  /// [AdaptiveAppBarAction.iconImage] (shown as a round avatar) as on the
  /// toolbar.
  final List<AdaptiveAppBarAction> actions;

  /// Whether each destination shows its label under its icon. Without them
  /// the rail is as narrow as the iPhone Duo bar, and the labels are only read
  /// by VoiceOver.
  final bool showLabels;

  /// Tint of the selected destination.
  final Color? tint;

  /// Margin between the capsules and the window's edges.
  static const double margin = 12;

  /// Width the rail takes, margins included.
  static double widthFor({bool showLabels = true}) =>
      (showLabels ? IOS26GlassCapsule.labeledWidth : IOS26GlassCapsule.width) +
      margin * 2;

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS26OrHigher()) return _buildGlass(context);
    return _buildMaterial(context);
  }

  /// Least space kept between the destinations and the actions.
  static const double _gap = 8;

  /// How the rail fits a column [height] tall: as asked for when there is
  /// room; otherwise without labels; then with the actions folded into one
  /// control that opens a menu of them (a phone turned sideways is about 345
  /// pt tall once the safe area and margins are taken).
  static RailPlan planFor({
    required double height,
    required int destinationCount,
    required int actionCount,
    required bool showLabels,
  }) {
    double tabs(bool labels) => labels
        ? IOS26GlassCapsule.labeledTabsHeight(destinationCount)
        : IOS26GlassCapsule.tabsHeight(destinationCount);
    double foot(bool fold) => actionCount == 0
        ? 0
        : _gap + IOS26GlassCapsule.actionsHeight(fold ? 1 : actionCount);

    final options = <RailPlan>[
      (showLabels: showLabels, foldActions: false),
      if (showLabels) (showLabels: false, foldActions: false),
      if (actionCount > 1) ...[
        (showLabels: showLabels, foldActions: true),
        if (showLabels) (showLabels: false, foldActions: true),
      ],
    ];
    for (final option in options) {
      if (tabs(option.showLabels) + foot(option.foldActions) <= height) {
        return option;
      }
    }
    return options.last;
  }

  Widget _buildGlass(BuildContext context) {
    // Each action's menu entries come back as `index * menuStride + entry`;
    // the folded actions come back as `foldedId + index`.
    const menuStride = 1000;
    const foldedId = 1000000;

    return SafeArea(
      right: false,
      child: Padding(
        padding: const EdgeInsets.all(margin),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final plan = planFor(
              height: constraints.maxHeight,
              destinationCount: destinations.length,
              actionCount: actions.length,
              showLabels: showLabels,
            );
            final width = plan.showLabels
                ? IOS26GlassCapsule.labeledWidth
                : IOS26GlassCapsule.width;
            final tabsHeight = plan.showLabels
                ? IOS26GlassCapsule.labeledTabsHeight(destinations.length)
                : IOS26GlassCapsule.tabsHeight(destinations.length);
            final badges = actions.fold<int>(
              0,
              (sum, action) => sum + (action.badgeCount ?? 0),
            );

            return SizedBox(
              width: width,
              child: Column(
                children: [
                  SizedBox(
                    height: tabsHeight,
                    child: IOS26GlassCapsule(
                      items: [
                        for (final destination in destinations)
                          GlassCapsuleItem.fromDestination(destination),
                      ],
                      selectedIndex: selectedIndex,
                      inset: IOS26GlassCapsule.tabsInset,
                      showLabels: plan.showLabels,
                      tint: tint,
                      onTap: onDestinationSelected,
                    ),
                  ),
                  const Spacer(),
                  if (actions.isNotEmpty && plan.foldActions)
                    SizedBox(
                      height: IOS26GlassCapsule.actionsHeight(1),
                      child: IOS26GlassCapsule(
                        items: [
                          GlassCapsuleItem(
                            symbol: 'ellipsis',
                            label: 'More',
                            badge: badges,
                            menu: [
                              for (var i = 0; i < actions.length; i++)
                                GlassCapsuleMenuEntry(
                                  id: foldedId + i,
                                  title: actions[i].effectiveLabel ?? '',
                                  symbol: actions[i].iosSymbol,
                                ),
                            ],
                          ),
                        ],
                        onTap: (_) {},
                        onMenuTap: (id) =>
                            actions[id - foldedId].press(context),
                      ),
                    )
                  else if (actions.isNotEmpty)
                    SizedBox(
                      height: IOS26GlassCapsule.actionsHeight(actions.length),
                      child: IOS26GlassCapsule(
                        items: [
                          for (var i = 0; i < actions.length; i++)
                            GlassCapsuleItem.fromAction(
                              actions[i],
                              menuIdBase: i * menuStride,
                            ),
                        ],
                        onTap: (i) => actions[i].press(context),
                        onMenuTap: (id) => actions[id ~/ menuStride]
                            .selectMenuItem(id % menuStride),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMaterial(BuildContext context) {
    Widget iconOf(Object? icon) => switch (icon) {
      IconData data => Icon(data),
      ImageProvider image => ClipOval(
        child: Image(image: image, width: 24, height: 24, fit: BoxFit.cover),
      ),
      Widget widget => widget,
      // An SF Symbol name: nothing to draw it with here.
      _ => const Icon(Icons.circle_outlined),
    };

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: showLabels
          ? NavigationRailLabelType.all
          : NavigationRailLabelType.none,
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: iconOf(destination.icon),
            selectedIcon: destination.selectedIcon == null
                ? null
                : iconOf(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
      trailing: actions.isEmpty
          ? null
          : Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: margin),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final action in actions)
                        IconButton(
                          tooltip: action.effectiveLabel,
                          onPressed: () => action.press(context),
                          icon: action.wrapWithBadge(
                            action.imageWidget ??
                                action.iconWidget ??
                                Icon(action.icon ?? Icons.circle_outlined),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
