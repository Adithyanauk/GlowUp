import 'package:flutter/material.dart';
import '../config/theme.dart';

class AnimationPlaceholder extends StatelessWidget {
  final double height;
  final String label;

  const AnimationPlaceholder({
    super.key,
    this.height = 220,
    this.label = 'Animation Coming Soon',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.appDivider,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_circle_outline_rounded,
              size: 48,
              color: AppColors.primary.withAlpha(180),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: context.appTextHint,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
