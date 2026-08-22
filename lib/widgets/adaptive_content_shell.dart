import 'package:flutter/material.dart';

class AdaptiveContentShell extends StatelessWidget {
  const AdaptiveContentShell({
    required this.compact,
    required this.expanded,
    this.breakpoint = 840,
    this.maxWidth = 1180,
    super.key,
  });

  final Widget compact;
  final Widget expanded;
  final double breakpoint;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                32,
              ),
              child: constraints.maxWidth >= breakpoint ? expanded : compact,
            ),
          ),
        );
      },
    );
  }
}
