import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/story.dart';
import '../repositories/catalog_repository.dart';

/// Visual metadata for editorial categories.
///
/// Stories themselves are never stored here: they are loaded from the public
/// backend. This catalog only maps server category identifiers to UI tokens.
class StoryCatalog {
  StoryCatalog._();

  static var categories = <StoryCategory>[
    StoryCategory(
      'architecture',
      'Arquitectura',
      Icons.architecture_rounded,
      AppColors.rust,
    ),
    StoryCategory(
      'mystery',
      'Misterios',
      Icons.auto_awesome_rounded,
      Color(0xFF5E537B),
    ),
    StoryCategory(
      'culture',
      'Cultura',
      Icons.theater_comedy_rounded,
      Color(0xFF9A6B24),
    ),
    StoryCategory(
      'neighborhood',
      'Barrios',
      Icons.holiday_village_rounded,
      AppColors.green,
    ),
    StoryCategory(
      'memory',
      'Memoria viva',
      Icons.photo_camera_back_rounded,
      Color(0xFF416A76),
    ),
    StoryCategory(
      'other',
      'Otras historias',
      Icons.menu_book_rounded,
      Color(0xFF6E705F),
    ),
  ];

  static var evidenceLevels = <MapEntry<String, String>>[
    const MapEntry('documented', 'Documentada'),
    const MapEntry('community', 'Aporte de vecinos'),
  ];

  static void applyRemote({
    required List<PublicCatalogEntry> categoryEntries,
    required List<PublicCatalogEntry> evidenceEntries,
  }) {
    if (categoryEntries.isNotEmpty) {
      categories = categoryEntries
          .map((entry) {
            final visual = resolve(entry.id, entry.label);
            return StoryCategory(
              entry.id,
              entry.label,
              visual.icon,
              visual.color,
              description: entry.description,
            );
          })
          .toList(growable: false);
    }
  }

  static StoryCategory resolve(String id, String label) {
    final normalizedId = id.trim().toLowerCase();
    for (final category in categories) {
      if (category.id == normalizedId) return category;
    }
    final normalizedLabel = _normalize(label);
    for (final category in categories) {
      if (_normalize(category.label) == normalizedLabel) return category;
    }
    final fallback = categories.firstWhere(
      (category) => category.id == 'other',
      orElse: () => const StoryCategory(
        'other',
        'Otras historias',
        Icons.menu_book_rounded,
        Color(0xFF6E705F),
      ),
    );
    return StoryCategory(normalizedId, label, fallback.icon, fallback.color);
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .trim();
}
