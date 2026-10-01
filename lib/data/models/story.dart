import 'package:flutter/material.dart';

enum StoryContributionOrigin {
  community,
  darditoTeam;

  String get label => switch (this) {
    StoryContributionOrigin.community => 'Proporcionada por la comunidad',
    StoryContributionOrigin.darditoTeam =>
      'Proporcionada por el equipo de Dardito',
  };
}

class StoryCategory {
  const StoryCategory(
    this.id,
    this.label,
    this.icon,
    this.color, {
    this.description,
  });
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String? description;
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
    required this.evidenceLabel,
    required this.mapX,
    required this.mapY,
    required this.latitude,
    required this.longitude,
    this.publicAuthor,
    this.featured = false,
    this.readMinutes = 3,
    this.likeCount = 0,
    this.contributionOrigin = StoryContributionOrigin.darditoTeam,
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
  final String evidence;
  final String evidenceLabel;
  final double mapX;
  final double mapY;
  final double latitude;
  final double longitude;
  final String? publicAuthor;
  final bool featured;
  final int readMinutes;
  final int likeCount;
  final StoryContributionOrigin contributionOrigin;

  CityStory withLikeCount(int value) => CityStory(
    id: id,
    title: title,
    subtitle: subtitle,
    category: category,
    neighborhood: neighborhood,
    period: period,
    shortStory: shortStory,
    fullStory: fullStory,
    source: source,
    evidence: evidence,
    evidenceLabel: evidenceLabel,
    mapX: mapX,
    mapY: mapY,
    latitude: latitude,
    longitude: longitude,
    publicAuthor: publicAuthor,
    featured: featured,
    readMinutes: readMinutes,
    likeCount: value,
    contributionOrigin: contributionOrigin,
  );
}
