import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

/// The KrishiDoc mark: a leaf above three field contours.
///
/// It is drawn in code so the same geometry stays crisp in the app shell,
/// onboarding and low-density Android devices without another asset load.
class KdBrandMark extends StatelessWidget {
  const KdBrandMark({this.size = 64, this.semanticLabel, super.key});

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mark = DecoratedBox(
      decoration: BoxDecoration(
        color: KdColors.actionLeaf,
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: const _BrandMarkPainter()),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: mark);
    return Semantics(image: true, label: semanticLabel, child: mark);
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final forest = Paint()
      ..color = KdColors.brandForest
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final gold = Paint()
      ..color = KdColors.brandGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .045
      ..strokeCap = StrokeCap.round;

    final leaf = Path()
      ..moveTo(size.width * .30, size.height * .48)
      ..cubicTo(
        size.width * .32,
        size.height * .22,
        size.width * .58,
        size.height * .16,
        size.width * .74,
        size.height * .23,
      )
      ..cubicTo(
        size.width * .73,
        size.height * .43,
        size.width * .57,
        size.height * .55,
        size.width * .37,
        size.height * .51,
      );
    canvas.drawPath(leaf, forest);
    canvas.drawLine(
      Offset(size.width * .35, size.height * .50),
      Offset(size.width * .62, size.height * .29),
      forest,
    );

    for (final y in [.64, .74, .84]) {
      final contour = Path()
        ..moveTo(size.width * .20, size.height * y)
        ..quadraticBezierTo(
          size.width * .48,
          size.height * (y - .08),
          size.width * .80,
          size.height * y,
        );
      canvas.drawPath(contour, y == .84 ? gold : forest);
    }
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => false;
}

enum KdHeroTone { forest, leaf }

/// High-emphasis branded surface for the primary purpose of a screen.
class KdHeroSurface extends StatelessWidget {
  const KdHeroSurface({
    required this.child,
    this.padding,
    this.tone = KdHeroTone.forest,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final KdHeroTone tone;

  @override
  Widget build(BuildContext context) {
    final tonal = tone == KdHeroTone.leaf;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tonal ? KdColors.actionLeaf : null,
        gradient: tonal
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [KdColors.brandForest, KdColors.primaryPressed],
              ),
        borderRadius: BorderRadius.circular(KdRadius.xl),
        boxShadow: tonal ? KdElevation.none : KdElevation.raised,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(KdSpacing.lg),
        child: child,
      ),
    );
  }
}

/// A single quiet container for related rows. Individual cards create a
/// stack of competing boxes; grouped rows preserve the relationship while
/// retaining full-size Material list targets and clear separators.
class KdGroupedSurface extends StatelessWidget {
  const KdGroupedSurface({
    required this.children,
    this.backgroundColor = KdColors.surface,
    super.key,
  });

  final List<Widget> children;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(KdRadius.lg),
      border: Border.all(color: KdColors.outlineSoft),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(KdRadius.lg),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1) const Divider(),
            ],
          ],
        ),
      ),
    ),
  );
}

/// A consistent icon container. It creates hierarchy without outlining the
/// whole section that follows it.
class KdIconWell extends StatelessWidget {
  const KdIconWell({
    required this.icon,
    this.backgroundColor = KdColors.primarySoft,
    this.foregroundColor = KdColors.primaryPressed,
    this.size = 48,
    super.key,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(KdRadius.md),
    ),
    child: SizedBox.square(
      dimension: size,
      child: Icon(
        icon,
        color: foregroundColor,
        size: kdScaledIcon(context, KdIconSize.md),
      ),
    ),
  );
}

/// Compact status label used for crop, connectivity and safety metadata.
class KdStatusPill extends StatelessWidget {
  const KdStatusPill({
    required this.label,
    this.icon,
    this.backgroundColor = KdColors.primarySoft,
    this.foregroundColor = KdColors.primaryPressed,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(KdRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KdSpacing.smd,
        vertical: KdSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: KdIconSize.sm, color: foregroundColor),
            const SizedBox(width: KdSpacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class KdSectionHeader extends StatelessWidget {
  const KdSectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: KdSpacing.xs),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KdColors.inkMuted),
          ),
        ],
      ],
    );
    if (action == null) return copy;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              copy,
              const SizedBox(height: KdSpacing.sm),
              action!,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: KdSpacing.smd),
            action!,
          ],
        );
      },
    );
  }
}
