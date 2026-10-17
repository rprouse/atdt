import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../reader/reader_theme.dart';

/// Hue, saturation and value sliders plus a hex field, for theme colours.
class ColourPicker extends StatefulWidget {
  const ColourPicker({
    required this.colour,
    required this.onChanged,
    super.key,
  });

  final Color colour;
  final ValueChanged<Color> onChanged;

  @override
  State<ColourPicker> createState() => _ColourPickerState();
}

class _ColourPickerState extends State<ColourPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.colour);
  late final _hex = TextEditingController(text: colourToHex(widget.colour));

  @override
  void didUpdateWidget(ColourPicker old) {
    super.didUpdateWidget(old);
    // A different role was selected, or the hex field set a new colour.
    if (widget.colour != _hsv.toColor()) {
      _hsv = HSVColor.fromColor(widget.colour);
      final hex = colourToHex(widget.colour);
      if (parseHexColour(_hex.text) != widget.colour) _hex.text = hex;
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set(HSVColor hsv) {
    setState(() => _hsv = hsv);
    final colour = hsv.toColor();
    _hex.text = colourToHex(colour);
    widget.onChanged(colour);
  }

  @override
  Widget build(BuildContext context) {
    Widget slider(
      String label,
      double value,
      double max,
      ValueChanged<double> onChanged,
    ) => Row(
      children: [
        SizedBox(width: 88, child: Text(label)),
        Expanded(
          child: Slider(
            key: ValueKey('slider-$label'),
            value: value.clamp(0, max),
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        slider('Hue', _hsv.hue, 360, (v) => _set(_hsv.withHue(v))),
        slider(
          'Saturation',
          _hsv.saturation,
          1,
          (v) => _set(_hsv.withSaturation(v)),
        ),
        slider('Brightness', _hsv.value, 1, (v) => _set(_hsv.withValue(v))),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.colour,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                key: const ValueKey('hex-field'),
                controller: _hex,
                decoration: const InputDecoration(
                  labelText: 'Hex',
                  hintText: '#RRGGBB',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: (text) {
                  final colour = parseHexColour(text);
                  if (colour == null) return;
                  setState(() => _hsv = HSVColor.fromColor(colour));
                  widget.onChanged(colour);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
