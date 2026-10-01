/// Local, deterministic typography hints. These are excerpts, not assertions.
enum ResponseEntityKind { date, quantity, name, number }

class ResponseEntity {
  const ResponseEntity(
    this.start,
    this.end,
    this.text,
    this.kind, {
    this.value,
    this.caption,
  });
  final int start;
  final int end;
  final String text;
  final ResponseEntityKind kind;
  final String? value;
  final String? caption;
}

abstract final class ResponseEntities {
  static const _months =
      'enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre';
  static final _dates = RegExp(
    r'\b(?:(?:hasta |desde |hacia |aproximadamente |a fines de |a principios de )?(?:la década de (?:los )?|los años |el año |año )\d{2,4}|(?:[12]?\d|3[01]) de (?:' +
        _months +
        r')(?: de \d{4})?|(?:en |desde |hasta |hacia |entre )(?:1[0-9]{3}|20[0-9]{2})(?:\s*(?:y|a|–|-)\s*(?:1[0-9]{3}|20[0-9]{2}))?)\b',
    caseSensitive: false,
  );
  static final _quantities = RegExp(
    r'\b(?:(?:unos|unas|aproximadamente|más de|menos de|casi|alrededor de)\s+)?(?:\d+(?:[.,]\d+)*|veinti(?:uno|dós|trés|cuatro|cinco|séis|siete|ocho|nueve)|diez|once|doce|trece|catorce|quince|dieciséis|diecisiete|dieciocho|diecinueve|veinte|treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa|cien|mil)(?:\s+y\s+(?:uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve))?\s*(?:metros cuadrados|kilómetros cuadrados|m²|km²|metros|kilómetros|escalones|habitantes|personas|hectáreas|años|pisos|cuadras|%)(?![a-záéíóúñ])',
    caseSensitive: false,
  );
  static final _names = RegExp(
    r'\b[A-ZÁÉÍÓÚÑ][a-záéíóúüñ]+(?:\s+(?:(?:de|del|la|las|los|el|y)\s+)*[A-ZÁÉÍÓÚÑ][a-záéíóúüñ]+)+',
  );
  static final _numbers = RegExp(r'\b\d+(?:[.,]\d+)*\b');
  static final _url = RegExp(r'https?://\S+');
  static final _numberValue = RegExp(
    r'\d+(?:[.,]\d+)*|veinti[a-záéíóúñ]+|diez|once|doce|trece|catorce|quince|dieciséis|diecisiete|dieciocho|diecinueve|veinte|treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa|cien|mil',
    caseSensitive: false,
  );

  static List<ResponseEntity> parse(String text) {
    final result = <ResponseEntity>[];
    final urls = _url.allMatches(text).toList();
    for (final entry in [
      (_dates, ResponseEntityKind.date),
      (_quantities, ResponseEntityKind.quantity),
      (_names, ResponseEntityKind.name),
      (_numbers, ResponseEntityKind.number),
    ]) {
      for (final match in entry.$1.allMatches(text)) {
        if (urls.any((url) => match.start < url.end && match.end > url.start) ||
            result.any((e) => match.start < e.end && match.end > e.start)) {
          continue;
        }
        final excerpt = match.group(0)!;
        String? value;
        String? caption;
        if (entry.$2 == ResponseEntityKind.date ||
            entry.$2 == ResponseEntityKind.quantity) {
          final number = _numberValue.firstMatch(excerpt);
          if (number != null) {
            // A range or compound number stays intact instead of becoming a
            // misleading single-number tile.
            final remainder = excerpt.substring(number.end);
            if (!RegExp(
              r'^\s*(?:y|a|–|-)\s*\w+',
              caseSensitive: false,
            ).hasMatch(remainder)) {
              value = number.group(0);
              caption =
                  '${excerpt.substring(0, number.start)}${excerpt.substring(number.end)}'
                      .trim()
                      .replaceAll(RegExp(r'\s+'), ' ');
            }
          }
        }
        result.add(
          ResponseEntity(
            match.start,
            match.end,
            excerpt,
            entry.$2,
            value: value,
            caption: caption,
          ),
        );
      }
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }
}
