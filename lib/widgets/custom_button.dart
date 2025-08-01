import 'package:flutter/material.dart';
import 'package:krishidoc/utils/colors.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final background = color ?? Theme.of(context).colorScheme.primary;
    final foreground =
        textColor ?? textPrimaryDarkColor; // Default to white from colors.dart

    return ElevatedButton.icon(
      icon: icon != null ? Icon(icon) : const SizedBox(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground, // Use textColor for text and icon
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
    );
  }
}
