import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'neon_tokens.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  Reusable UI atoms for the Neon design system. Every screen builds from
///  these instead of ad-hoc containers, so the look stays consistent.
/// ─────────────────────────────────────────────────────────────────────────

/// Primary CTA — gradient fill, glow, press-scale feedback.
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final IconData? icon;
  final bool busy;
  final EdgeInsets padding;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient = Neon.gVioletCyan,
    this.icon,
    this.busy = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    return AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: Neon.fast,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedOpacity(
          duration: Neon.fast,
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(Neon.rPill),
              boxShadow: enabled
                  ? Neon.glow2(widget.gradient.colors.first,
                      widget.gradient.colors.last)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.busy) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, size: 19, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action — outlined ghost with a subtle neon border.
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Color accent;

  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.accent = Neon.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Neon.textHi,
        side: BorderSide(color: accent.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Neon.rPill)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Text(label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Frosted glassmorphism card — the default container of the app.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double radius;
  final Color? tint;
  final Gradient? borderGradient;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Neon.s4),
    this.margin,
    this.radius = Neon.rLg,
    this.tint,
    this.borderGradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? Colors.white).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(radius),
            border: borderGradient == null ? Border.all(color: Neon.line) : null,
          ),
          child: child,
        ),
      ),
    );

    final bordered = borderGradient == null
        ? card
        : Container(
            padding: const EdgeInsets.all(1.2),
            decoration: BoxDecoration(
              gradient: borderGradient,
              borderRadius: BorderRadius.circular(radius + 1.2),
            ),
            child: card,
          );

    final content = margin == null
        ? bordered
        : Padding(padding: margin!, child: bordered);
    if (onTap == null) return content;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: content,
    );
  }
}

/// Small neon label chip / badge.
class NeonChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  const NeonChip({
    super.key,
    required this.label,
    this.color = Neon.cyan,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(Neon.rPill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Gradient-text brand / heading treatment.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const GradientText(this.text,
      {super.key, required this.style, this.gradient = Neon.gVioletCyan});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

/// Section header with a tiny gradient tick — replaces plain bold labels.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Neon.s1, Neon.s5, Neon.s1, Neon.s3),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: Neon.gVioletPink,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Empty state — icon in a glowing gradient ring + guidance copy.
class NeonEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  const NeonEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Neon.s7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: Neon.gVioletCyan,
                boxShadow: Neon.glow(Neon.violet, blur: 34, alpha: 0.35),
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Neon.surface),
                child: Icon(icon, size: 34, color: Neon.cyan),
              ),
            ),
            const SizedBox(height: Neon.s5),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (body != null) ...[
              const SizedBox(height: Neon.s2),
              Text(body!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Neon.textLo, height: 1.4)),
            ],
            if (action != null) ...[
              const SizedBox(height: Neon.s5),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry affordance.
class NeonErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const NeonErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return NeonEmptyState(
      icon: Icons.bolt_rounded,
      title: 'Something broke the circuit',
      body: message,
      action: onRetry == null
          ? null
          : GradientButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              gradient: Neon.gPinkViolet,
              onPressed: onRetry,
            ),
    );
  }
}

/// Gradient loading spinner (ring sweep).
class NeonLoader extends StatefulWidget {
  final double size;
  const NeonLoader({super.key, this.size = 42});

  @override
  State<NeonLoader> createState() => _NeonLoaderState();
}

class _NeonLoaderState extends State<NeonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
            shape: BoxShape.circle, gradient: Neon.gOrb),
        padding: const EdgeInsets.all(3),
        child: const DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: Neon.bg),
        ),
      ),
    );
  }
}

/// Ambient background — deep space with two soft radial neon washes.
/// Wrap any Scaffold body with this for the signature backdrop.
class NeonBackdrop extends StatelessWidget {
  final Widget child;
  const NeonBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Neon.bg),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _wash(Neon.violet, 340),
          ),
          Positioned(
            bottom: -140,
            right: -100,
            child: _wash(Neon.cyan, 380),
          ),
          child,
        ],
      ),
    );
  }

  Widget _wash(Color c, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              c.withValues(alpha: 0.16),
              c.withValues(alpha: 0.0),
            ]),
          ),
        ),
      );
}
