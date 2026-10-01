import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';

class PublicCatalogEntry {
  const PublicCatalogEntry(this.id, this.label, {this.description});

  final String id;
  final String label;
  final String? description;
}

class PublicCatalogs {
  const PublicCatalogs({
    required this.categories,
    required this.neighborhoods,
    required this.evidenceLevels,
  });

  final List<PublicCatalogEntry> categories;
  final List<PublicCatalogEntry> neighborhoods;
  final List<PublicCatalogEntry> evidenceLevels;
}

class RemoteCatalogRepository {
  RemoteCatalogRepository({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  Future<PublicCatalogs> fetch() async {
    final response = await _client
        .get(
          BackendConfig.publicCatalogsEndpoint,
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200 || response.bodyBytes.length > 256 * 1024) {
      throw StateError('No fue posible cargar los catálogos editoriales.');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
      throw StateError('El catálogo editorial no es compatible.');
    }
    final rawCatalogs = decoded['catalogs'];
    if (rawCatalogs is! Map<String, dynamic>) {
      throw StateError('El catálogo editorial es inválido.');
    }
    return PublicCatalogs(
      categories: _entries(rawCatalogs['categories']),
      neighborhoods: _entries(rawCatalogs['neighborhoods']),
      evidenceLevels: _entries(rawCatalogs['evidenceLevels']),
    );
  }

  List<PublicCatalogEntry> _entries(Object? value) {
    if (value is! List || value.isEmpty || value.length > 120) {
      throw StateError('Una sección del catálogo editorial es inválida.');
    }
    final entries = <PublicCatalogEntry>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw StateError('Un valor del catálogo editorial es inválido.');
      }
      final id = item['id'];
      final label = item['label'];
      final rawDescription = item['description'];
      if (id is! String || label is! String || id.isEmpty || label.isEmpty) {
        throw StateError('Un valor del catálogo editorial está incompleto.');
      }
      final description =
          rawDescription is String && rawDescription.trim().isNotEmpty
          ? rawDescription.trim()
          : null;
      entries.add(PublicCatalogEntry(id, label, description: description));
    }
    return List.unmodifiable(entries);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
