import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/services/announcement_service.dart';

class CityAutocomplete extends StatefulWidget {
  final String label;
  final String? initialValue;
  final ValueChanged<String> onSelected;
  final String? hintText;

  const CityAutocomplete({
    super.key,
    required this.label,
    this.initialValue,
    required this.onSelected,
    this.hintText,
  });

  @override
  State<CityAutocomplete> createState() => _CityAutocompleteState();
}

class _CityAutocompleteState extends State<CityAutocomplete> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _service = AnnouncementService();
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchCities(value);
    });
  }

  Future<void> _searchCities(String query) async {
    if (query.length < 2) {
      _removeOverlay();
      return;
    }

    try {
      final results = await _service.searchCities(query);
      _suggestions = results;
      if (_suggestions.isNotEmpty && _focusNode.hasFocus) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } catch (_) {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primarySky.withValues(alpha: 0.3),
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final city = _suggestions[index];
                  final name = city['name'] as String? ?? '';
                  final country = city['country'] as String? ?? '';

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined,
                        size: 18, color: AppTheme.primarySky),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: country.isNotEmpty ? Text(country) : null,
                    onTap: () {
                      _controller.text = name;
                      widget.onSelected(name);
                      _removeOverlay();
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText ?? 'Rechercher une ville...',
          prefixIcon: const Icon(Icons.location_city, size: 20),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _controller.clear();
                    widget.onSelected('');
                    _removeOverlay();
                  },
                )
              : null,
        ),
        onChanged: (value) {
          _onChanged(value);
          widget.onSelected(value);
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Veuillez sélectionner une ville';
          }
          return null;
        },
      ),
    );
  }
}
