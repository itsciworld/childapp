import 'package:flutter/material.dart';

/// The kind of toast — drives the accent colour + default icon.
enum ToastType { success, error, warning, info }

/// Shows a floating, auto-dismissing toast at the top of the screen.
///
/// Use this everywhere instead of [SnackBar]. It is inserted into the ROOT
/// [Overlay] (the app Navigator's overlay), so it stays visible even across a
/// route push that happens right after — e.g. showing a success toast and then
/// navigating to the next screen.
///
/// Safe to call from `build`, a Riverpod `ref.listen` callback, or a button
/// handler: the insert is deferred to the next frame so it never mutates the
/// overlay mid-build.
///
/// ```dart
/// showAppToast(
///   context: context,
///   title: 'Success',
///   subtitle: 'Pairing code verified',
///   type: ToastType.success,
/// );
/// ```
void showAppToast({
  required BuildContext context,
  required String title,
  required String subtitle,
  ToastType type = ToastType.success,
  IconData? icon,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _ToastOverlay(
      title: title,
      subtitle: subtitle,
      type: type,
      icon: icon,
      onDismiss: remove,
    ),
  );

  // Defer so it's safe to call during build / listen callbacks.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (removed) return;
    overlay.insert(entry);
  });
}

/// ─────────────────────────────────────────────
/// TYPE EXTENSION
/// ─────────────────────────────────────────────
extension _ToastTypeProps on ToastType {
  Color get accent {
    switch (this) {
      case ToastType.success:
        return const Color(0xFF22C55E);
      case ToastType.error:
        return const Color(0xFFEF4444);
      case ToastType.warning:
        return const Color(0xFFF59E0B);
      case ToastType.info:
        return const Color(0xFF3B82F6);
    }
  }

  IconData get defaultIcon {
    switch (this) {
      case ToastType.success:
        return Icons.check_circle_outline_rounded;
      case ToastType.error:
        return Icons.error_outline_rounded;
      case ToastType.warning:
        return Icons.warning_amber_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }
}

/// ─────────────────────────────────────────────
/// TOAST OVERLAY
/// ─────────────────────────────────────────────
class _ToastOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final ToastType type;
  final IconData? icon;
  final VoidCallback onDismiss;

  const _ToastOverlay({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.onDismiss,
    this.icon,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final Animation<double> _progress;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    /// 🔥 ENTRY (right → center)
    _slide = Tween<Offset>(
      begin: const Offset(1, 0), // 👉 from RIGHT
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOutCubic),
      ),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.2));

    /// 🔥 PROGRESS (empty → full)
    _progress = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));

    /// 🚀 START
    _ctrl.forward();

    /// 🔥 WHEN DONE → DISMISS
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    _ctrl.stop();
    widget.onDismiss();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // If dragged more than 100px or fast swipe, dismiss immediately
    if (_dragOffset.abs() > 100 ||
        details.velocity.pixelsPerSecond.dx.abs() > 500) {
      _ctrl.stop();
      widget.onDismiss();
    } else {
      // Reset position
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final t = widget.type;

    return Positioned(
      top: topPad + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),

                    /// 🔥 3 SHADOW LAYERS
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        offset: const Offset(0, 8),
                        blurRadius: 10,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        offset: const Offset(0, 6),
                        blurRadius: 30,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        offset: const Offset(0, 16),
                        blurRadius: 24,
                      ),
                    ],
                  ),

                  /// 🔥 STACK (content + animated border)
                  child: Stack(
                    children: [
                      /// CONTENT
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: t.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.icon ?? t.defaultIcon,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// TITLE
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  /// SUBTITLE
                                  Text(
                                    widget.subtitle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black54,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            /// 🔥 CLOSE BUTTON
                            GestureDetector(
                              onTap: _dismiss,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      /// 🔥 ANIMATED BOTTOM BAR
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedBuilder(
                          animation: _progress,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment.centerRight,
                              child: FractionallySizedBox(
                                widthFactor: _progress.value,
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: t.accent,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
