// ══════════════════════════════════════════════════════════
//  shimmer_loading.dart
// ══════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

class ShimmerLoadingList extends StatelessWidget {
  const ShimmerLoadingList({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 3, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          baseColor: AppTheme.surfaceWarm, highlightColor: AppTheme.surfaceHigh,
          child: Container(height: 110, decoration: BoxDecoration(color: AppTheme.surfaceWarm, borderRadius: BorderRadius.circular(20))),
        ),
      ),
    );
  }
}

class ShimmerLoadingGrid extends StatelessWidget {
  const ShimmerLoadingGrid({super.key});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 14, childAspectRatio: 0.78,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppTheme.surfaceWarm, highlightColor: AppTheme.surfaceHigh,
        child: Container(decoration: BoxDecoration(color: AppTheme.surfaceWarm, borderRadius: BorderRadius.circular(18))),
      ),
    );
  }
}

class ShimmerLoadingHorizontal extends StatelessWidget {
  const ShimmerLoadingHorizontal({super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, itemCount: 3,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Shimmer.fromColors(
            baseColor: AppTheme.surfaceWarm, highlightColor: AppTheme.surfaceHigh,
            child: Container(width: 160, decoration: BoxDecoration(color: AppTheme.surfaceWarm, borderRadius: BorderRadius.circular(18))),
          ),
        ),
      ),
    );
  }
}

class ShimmerLine extends StatelessWidget {
  final double width;
  final double height;
  const ShimmerLine({super.key, this.width = double.infinity, this.height = 14});
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceWarm, highlightColor: AppTheme.surfaceHigh,
      child: Container(width: width, height: height, decoration: BoxDecoration(color: AppTheme.surfaceWarm, borderRadius: BorderRadius.circular(8))),
    );
  }
}