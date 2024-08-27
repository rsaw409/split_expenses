import 'package:flutter/material.dart';

class CustomChip extends StatelessWidget {
  const CustomChip({
    super.key,
    required this.label,
    required this.radius,
    required this.selected,
    required this.onSelect,
    this.margin = const EdgeInsets.all(8.0),
  });

  final String label;
  final double radius;
  final bool selected;
  final Function onSelect;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelect(!selected),
      child: Container(
        margin: margin,
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8), // Space between label and avatar
            CircleAvatar(
              radius: radius,
              // Show border when selected
              foregroundColor: selected ? Colors.orange : Colors.transparent,
              backgroundColor:
                  selected ? Colors.purple.withOpacity(0.2) : Colors.grey[200],
              child: Center(
                child: Text(
                  _getInitials(label),
                  style: TextStyle(
                    fontSize: radius * 0.6, // Adjust font size based on radius
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _getInitials(String label) {
  List<String> words = label.split(" ");
  String initials = words.map((word) => word[0]).join();
  return initials.toUpperCase();
}
