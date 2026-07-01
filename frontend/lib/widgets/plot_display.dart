import 'package:flutter/material.dart';
import 'dart:convert';

class PlotDisplay extends StatelessWidget {
  final String? base64Image;
  final String title;
  final double height;

  const PlotDisplay({
    super.key,
    this.base64Image,
    required this.title,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    if (base64Image == null) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            '$title not available',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    String imageData = base64Image!;
    if (imageData.contains(',')) {
      imageData = imageData.split(',').last;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(imageData),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Text('Failed to load plot'),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}