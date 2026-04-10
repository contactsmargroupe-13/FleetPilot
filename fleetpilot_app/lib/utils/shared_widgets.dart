import 'package:flutter/material.dart';
import 'design_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DCStatusBadge — Unified status badge (pill shape)
// ─────────────────────────────────────────────────────────────────────────────

class DCStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final double fontSize;

  const DCStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DC.rPill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: DC.body(fontSize, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DCEmptyState — Centered empty state with icon, title, optional subtitle
// ─────────────────────────────────────────────────────────────────────────────

class DCEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const DCEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: DC.textTertiary),
            const SizedBox(height: 16),
            Text(
              title,
              style: DC.body(15, weight: FontWeight.w500, color: DC.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: DC.body(13, color: DC.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DCShimmerLoading — Animated skeleton placeholder
// ─────────────────────────────────────────────────────────────────────────────

class DCShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const DCShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<DCShimmerLoading> createState() => _DCShimmerLoadingState();
}

class _DCShimmerLoadingState extends State<DCShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorTween;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _colorTween = ColorTween(
      begin: DC.surface2,
      end: DC.surface3,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorTween,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _colorTween.value,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DCShimmerList — Pre-built shimmer list for loading states
// ─────────────────────────────────────────────────────────────────────────────

class DCShimmerList extends StatelessWidget {
  final int itemCount;

  const DCShimmerList({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: DC.screenH, vertical: 12),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => DCShimmerLoading(
        width: double.infinity,
        height: 80,
        borderRadius: DC.rCard,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DCUndoSnackBar — Show undo snackbar helper
// ─────────────────────────────────────────────────────────────────────────────

void showUndoSnackBar(BuildContext context, String message, VoidCallback onUndo) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Annuler',
          textColor: DC.primaryLight,
          onPressed: onUndo,
        ),
      ),
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// DCStickyBottomBar — Sticky bottom action bar for forms
// ─────────────────────────────────────────────────────────────────────────────

class DCStickyBottomBar extends StatelessWidget {
  final List<Widget> children;

  const DCStickyBottomBar({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DC.border)),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DCFormField — Enhanced form field with inline validation
// ─────────────────────────────────────────────────────────────────────────────

class DCFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final String? suffix;
  final bool readOnly;
  final VoidCallback? onTap;

  const DCFormField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.prefixIcon,
    this.suffix,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: DC.body(14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: DC.textSecondary)
            : null,
        suffixText: suffix,
        suffixStyle: DC.body(13, color: DC.textTertiary),
      ),
    );
  }
}
