import 'package:flutter/material.dart';

enum EvidenceLevel { documented, oralTradition, community }

class StoryCategory {
  const StoryCategory(this.id, this.label, this.icon, this.color);
  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

class CityStory {
  const CityStory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.neighborhood,
    required this.period,
    required this.shortStory,
    required this.fullStory,
    required this.source,
    required this.evidence,
    required this.mapX,
    required this.mapY,
    required this.latitude,
    required this.longitude,
    this.featured = false,
    this.readMinutes = 3,
  });

  final String id;
  final String title;
  final String subtitle;
  final StoryCategory category;
  final String neighborhood;
  final String period;
  final String shortStory;
  final String fullStory;
  final String source;
  final EvidenceLevel evidence;
  final double mapX;
  final double mapY;
  final double latitude;
  final double longitude;
  final bool featured;
  final int readMinutes;
}
