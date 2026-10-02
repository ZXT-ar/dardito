import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'reading_palette.dart';

/// A book plate sized from the actual photograph, with no letterboxed canvas.
class StoryPlate extends StatefulWidget {
  const StoryPlate({
    super.key,
    required this.image,
    required this.title,
    this.number = 1,
    this.leading,
  });
  final ImageProvider image;
  final String title;
  final int number;
  final Widget? leading;

  @override
  State<StoryPlate> createState() => _StoryPlateState();
}

class _StoryPlateState extends State<StoryPlate> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _ratio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(StoryPlate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _ratio = null;
    _stream = widget.image.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (info, synchronousCall) {
        final ratio = info.image.width / info.image.height;
        info.dispose();
        if (mounted) setState(() => _ratio = ratio);
      },
      onError: (Object error, StackTrace? stack) {
        if (mounted) setState(() => _ratio = null);
      },
    );
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  String get _title => widget.title.replaceFirst(
    RegExp(r'^Imagen de\s+', caseSensitive: false),
    '',
  );
  String get _folio => 'LÁMINA ${widget.number.toString().padLeft(2, '0')}';

  Widget _photo(double width) => SizedBox(
    width: width,
    height: width / _ratio!,
    child: Image(
      image: widget.image,
      fit: BoxFit.contain,
      semanticLabel: widget.title,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );

  void _open() => showDialog<void>(
    context: context,
    barrierColor: AppColors.navy.withValues(alpha: .86),
    builder: (context) => LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.max(
          1.0,
          math.min(1000.0, constraints.maxWidth - 56),
        );
        final photoHeight = math.max(1.0, constraints.maxHeight - 210);
        final width = math.min(maxWidth, photoHeight * _ratio!);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: ReadingPalette.of(context).paper,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          child: SizedBox(
            width: width + 24,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _folio,
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.8,
                              color: ReadingPalette.of(context).muted,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar imagen',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: width,
                      height: width / _ratio!,
                      child: InteractiveViewer(
                        maxScale: 4,
                        child: _photo(width),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_ratio == null) return widget.leading ?? const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          math.max(1.0, constraints.maxWidth - 26),
          400 * _ratio!,
        );
        final plate = Padding(
          padding: EdgeInsets.only(
            top: widget.leading == null ? 28 : 0,
            bottom: 8,
          ),
          child: Align(
            alignment: Alignment.center,
            child: Container(
              width: width + 26,
              decoration: BoxDecoration(
                color: ReadingPalette.of(context).plate,
                border: Border.all(color: ReadingPalette.of(context).line),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x19604D29),
                    blurRadius: 12,
                    offset: Offset(2, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _open,
                  child: Semantics(
                    button: true,
                    label: 'Ampliar ${widget.title}',
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _photo(width),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _folio,
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1.6,
                                    color: ReadingPalette.of(context).muted,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.open_in_full,
                                size: 14,
                                color: ReadingPalette.of(context).muted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _title,
                            style: TextStyle(
                              fontFamily: 'Lora',
                              fontSize: 14,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                              color: ReadingPalette.of(context).ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final text = widget.leading;
        if (text == null) return plate;
        final frameWidth = width + 26;
        final textWidth = constraints.maxWidth - frameWidth - 24;
        final alongside =
            frameWidth <= constraints.maxWidth * .6 &&
            textWidth >= 220 * MediaQuery.textScalerOf(context).scale(1);
        if (alongside) {
          return Row(
            key: const ValueKey('story-text-beside-image'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: text),
              const SizedBox(width: 24),
              SizedBox(width: frameWidth, child: plate),
            ],
          );
        }
        return Column(
          key: const ValueKey('story-image-below-text'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [text, const SizedBox(height: 28), plate],
        );
      },
    );
  }
}
