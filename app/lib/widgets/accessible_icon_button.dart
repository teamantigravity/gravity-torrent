import 'package:flutter/material.dart';

/// An [IconButton] that always carries a semantic label for screen readers.
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double? iconSize;
  final Color? color;
  final String? tooltip;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.iconSize,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, semanticLabel: semanticLabel),
      iconSize: iconSize,
      color: color,
      tooltip: tooltip ?? semanticLabel,
      onPressed: onPressed,
    );
  }
}
