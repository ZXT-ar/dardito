import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Static reference map behind the hero, rendered as pale ink on warm paper.
class HomeHeroBackdrop extends StatelessWidget {
  const HomeHeroBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 650),
    clipBehavior: Clip.hardEdge,
    decoration: const BoxDecoration(color: AppColors.heroPaper),
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    // Map luminance becomes a restrained sepia line on paper.
                    colorFilter: const ColorFilter.matrix([
                      -.0468,
                      -.1573,
                      -.0159,
                      0,
                      247,
                      -.0532,
                      -.1788,
                      -.0180,
                      0,
                      239,
                      -.0638,
                      -.2146,
                      -.0216,
                      0,
                      218,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
                    child: Image.asset(
                      'assets/map/hero_la_plata_blue.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, .42, 1],
                        colors: [
                          Color(0x30F7EFDA),
                          Color(0x00F7EFDA),
                          Color(0x70F7EFDA),
                        ],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: [0, .38, 1],
                        colors: [
                          Color(0xA0F7EFDA),
                          Color(0x35F7EFDA),
                          Color(0x50F7EFDA),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
        const Positioned(
          right: 8,
          bottom: 5,
          child: IgnorePointer(
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 9, color: Color(0xFF756B55)),
            ),
          ),
        ),
      ],
    ),
  );
}
