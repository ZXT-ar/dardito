import 'package:flutter/material.dart';

/// Static reference map behind the hero, softened by two navy gradients.
class HomeHeroBackdrop extends StatelessWidget {
  const HomeHeroBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 650),
    clipBehavior: Clip.hardEdge,
    decoration: const BoxDecoration(color: Color(0xFF102937)),
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/map/hero_la_plata_blue.png',
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, .42, 1],
                        colors: [
                          Color(0x7806131E),
                          Color(0x0006131E),
                          Color(0xD406131E),
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
                          Color(0xCF06131E),
                          Color(0x8F06131E),
                          Color(0xD806131E),
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
              style: TextStyle(fontSize: 9, color: Color(0xFF9CACB5)),
            ),
          ),
        ),
      ],
    ),
  );
}
