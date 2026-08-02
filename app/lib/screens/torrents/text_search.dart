import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/utils/device.dart';

class TextSearchController {
  VoidCallback? _onExpand;
  VoidCallback? _onFocus;
  VoidCallback? _onClear;

  void expand() => _onExpand?.call();

  void focus() => _onFocus?.call();

  void clear() => _onClear?.call();

  void dispose() {
    _onExpand = null;
    _onFocus = null;
    _onClear = null;
  }
}

class TextSearch extends StatefulWidget {
  final Function(String) onChange;
  final Function(String)? onSubmitted;
  final TextSearchController? controller;

  const TextSearch({
    super.key,
    required this.onChange,
    this.onSubmitted,
    this.controller,
  });

  @override
  State<TextSearch> createState() => _TextSearchState();
}

class _TextSearchState extends State<TextSearch> {
  final _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filterController.addListener(
      () => widget.onChange(_filterController.text),
    );
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpandableSearchFormField(
      controller: _filterController,
      onSubmitted: widget.onSubmitted,
      searchController: widget.controller,
    );
  }
}

class ExpandableSearchFormField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String)? onSubmitted;
  final TextSearchController? searchController;

  const ExpandableSearchFormField({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.searchController,
  });

  @override
  State<ExpandableSearchFormField> createState() =>
      _ExpandableSearchFormFieldState();
}

class _ExpandableSearchFormFieldState extends State<ExpandableSearchFormField> {
  bool _isExpanded = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _updateClearState();
    widget.controller.addListener(_updateClearState);
    widget.searchController?._onExpand = _expand;
    widget.searchController?._onFocus = _focus;
    widget.searchController?._onClear = _clear;
  }

  @override
  void didUpdateWidget(covariant ExpandableSearchFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateClearState);
      _updateClearState();
      widget.controller.addListener(_updateClearState);
    }
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController?._onExpand = null;
      oldWidget.searchController?._onFocus = null;
      oldWidget.searchController?._onClear = null;
      widget.searchController?._onExpand = _expand;
      widget.searchController?._onFocus = _focus;
      widget.searchController?._onClear = _clear;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateClearState);
    _focusNode.dispose();
    widget.searchController?._onExpand = null;
    widget.searchController?._onFocus = null;
    widget.searchController?._onClear = null;
    super.dispose();
  }

  void _updateClearState() {
    setState(() {});
  }

  void _expand() {
    if (!_isExpanded && mounted) {
      setState(() => _isExpanded = true);
    }
  }

  void _focus() {
    _expand();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _clear() {
    if (!mounted) return;
    widget.controller.clear();
    if (_isExpanded) {
      setState(() => _isExpanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    final controller = widget.controller;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isExpanded
          ? isMobileSize(context)
              ? 160
              : 240
          : 48,
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: _isExpanded
              ? isMobileSize(context)
                  ? 160
                  : 240
              : 48,
          child: Row(
            children: [
              Expanded(
                child: _isExpanded
                    ? TextFormField(
                        controller: controller,
                        focusNode: _focusNode,
                        autofocus: false,
                        onFieldSubmitted: (value) {
                          widget.onSubmitted?.call(controller.text);
                        },
                        decoration: InputDecoration(
                          labelText: '${localizations.search}...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: controller.clear,
                                  tooltip: MaterialLocalizations.of(context)
                                      .deleteButtonTooltip,
                                )
                              : null,
                          border: InputBorder.none,
                        ),
                      )
                    : const SizedBox(),
              ),
              IconButton(
                tooltip: _isExpanded
                    ? MaterialLocalizations.of(context).closeButtonTooltip
                    : localizations.search,
                icon: Icon(_isExpanded ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                    if (!_isExpanded) {
                      controller.clear();
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
