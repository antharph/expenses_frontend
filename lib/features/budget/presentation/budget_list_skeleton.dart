import 'package:flutter/material.dart';

/// Placeholder cards shown while budgets load.
class BudgetListSkeleton extends StatelessWidget {
  const BudgetListSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Material(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bone(width: 140, height: 18),
                const SizedBox(height: 8),
                _Bone(width: 100, height: 14),
                const SizedBox(height: 20),
                _Bone(width: 72, height: 12),
                const SizedBox(height: 6),
                _Bone(width: 120, height: 32),
                const SizedBox(height: 16),
                _Bone(width: double.infinity, height: 10, radius: 8),
                const SizedBox(height: 10),
                _Bone(width: 160, height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({
    required this.width,
    required this.height,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
