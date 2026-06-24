import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
class BottomNavShell extends StatelessWidget {
  final Widget child;
  final String location;

  const BottomNavShell({
    super.key,
    required this.child,
    required this.location,
  });

  static const _tabs = [
    _NavTab(path: '/dashboard', icon: Icons.home_rounded),
    _NavTab(path: '/actions', icon: Icons.track_changes_rounded),
    _NavTab(path: '/journal', icon: Icons.menu_book_rounded),
    _NavTab(path: '/mindset', icon: Icons.auto_awesome_rounded),
  ];

  int get _selectedIndex {
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Chat is a focused full-screen experience: hide the floating nav so the
    // conversation can fill the view. The chat header provides a way back.
    final hideNav = location.startsWith('/chat');
    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      extendBody: true,
      bottomNavigationBar: hideNav
          ? null
          : Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                // Sit low against the bottom edge (Instagram-style). On devices
                // with a home indicator, hug the safe area; otherwise keep a
                // small margin.
                bottom: bottomPadding > 0
                    ? bottomPadding
                    : AppSpacing.bottomNavMargin,
              ),
              child: _FloatingPillNav(
                selectedIndex: _selectedIndex,
                onTap: (i) => context.go(_tabs[i].path),
                onCoachTap: () => context.go('/chat'),
                tabs: _tabs,
              ),
            ),
    );
  }
}

class _FloatingPillNav extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCoachTap;
  final List<_NavTab> tabs;

  const _FloatingPillNav({
    required this.selectedIndex,
    required this.onTap,
    required this.onCoachTap,
    required this.tabs,
  });

  // Center coach button + notch geometry (kept in sync across the clipper,
  // painters, button position and the reserved row gap).
  static const double _coachButtonSize = 56.0;
  static const double _notchRadius = 34.0;
  // The button is raised by its radius so its center rests on the pill's top
  // edge, sitting half-in / half-out of the notch.
  static const double _coachRaise = _coachButtonSize / 2;

  /// Rounded pill with a circular notch carved out of the top-center edge.
  /// Shared by the clipper and both painters so the shape never drifts.
  static Path notchedPath(Size size, double notchRadius) {
    final base = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.height / 2),
      ));
    final notch = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, 0),
        radius: notchRadius,
      ));
    return Path.combine(PathOperation.difference, base, notch);
  }

  @override
  State<_FloatingPillNav> createState() => _FloatingPillNavState();
}

class _FloatingPillNavState extends State<_FloatingPillNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  // Interpolates the selected tab as a continuous double (0.0–3.0) so the
  // pill position can be linearly lerped between tab centers.
  late Animation<double> _anim;

  // Each tab slot: 4px outer padding each side + 16px inner padding each side
  // + 22px icon = 62px total. The sliding pill (inner container) is 54×42px.
  static const double _tabSlotW = 62.0;
  static const double _pillW = 54.0;
  static const double _pillH = 42.0;
  // Width of the notch spacer that separates the two tab groups.
  static const double _notchGap = 72.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _anim = AlwaysStoppedAnimation(widget.selectedIndex.toDouble());
  }

  @override
  void didUpdateWidget(_FloatingPillNav old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _anim = Tween<double>(
        begin: old.selectedIndex.toDouble(),
        end: widget.selectedIndex.toDouble(),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// X-coordinate of the center of each tab slot, measured from the left edge
  /// of the pill container, given the container's full rendered width [W].
  double _tabCenterX(int index, double W) {
    final sideW = (W - _notchGap) / 2.0;
    final gap = (sideW - 2 * _tabSlotW) / 3.0;
    final localCenters = [
      gap + _tabSlotW / 2,
      gap * 2 + _tabSlotW * 1.5,
    ];
    final sectionOffset = index < 2 ? 0.0 : sideW + _notchGap;
    return sectionOffset + localCenters[index % 2];
  }

  /// Left edge of the sliding pill for the given animation value and width.
  double _pillLeft(double animValue, double W) {
    final lo = animValue.floor().clamp(0, widget.tabs.length - 1);
    final hi = animValue.ceil().clamp(0, widget.tabs.length - 1);
    final t = animValue - lo;
    final cx = lerpDouble(_tabCenterX(lo, W), _tabCenterX(hi, W), t)!;
    return cx - _pillW / 2;
  }

  Widget _buildTab(int i) {
    final selected = i == widget.selectedIndex;
    return GestureDetector(
      onTap: () => widget.onTap(i),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: _pillW,
          height: _pillH,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                widget.tabs[i].icon,
                key: ValueKey(selected),
                color: selected ? Colors.white : AppColors.textMuted,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.bottomNavHeight + _FloatingPillNav._coachRaise,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The notched glass pill sits at the bottom; the coach button docks
          // into the cutout and rises above it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              painter: const _NotchShadowPainter(
                  notchRadius: _FloatingPillNav._notchRadius),
              foregroundPainter: const _NotchBorderPainter(
                  notchRadius: _FloatingPillNav._notchRadius),
              child: ClipPath(
                clipper:
                    const _NotchedPillClipper(_FloatingPillNav._notchRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: SizedBox(
                    height: AppSpacing.bottomNavHeight,
                    child: LayoutBuilder(
                      builder: (_, constraints) {
                        return Stack(
                          children: [
                            // ── 1. Full-height translucent background ───────
                            Positioned.fill(
                              child: Container(
                                color:
                                    AppColors.surface.withValues(alpha: 0.50),
                              ),
                            ),

                            // ── 2. Top glass specular highlight ─────────────
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              child: Container(
                                height: 28,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x14FFFFFF), // white 8%
                                      Color(0x00FFFFFF), // transparent
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // ── 3. Sliding gradient pill (above background, below icons) ──
                            AnimatedBuilder(
                              animation: _anim,
                              builder: (_, __) {
                                final left = _pillLeft(
                                    _anim.value, constraints.maxWidth);
                                return Positioned(
                                  left: left,
                                  top: (AppSpacing.bottomNavHeight - _pillH) /
                                      2,
                                  child: const _SlidingPill(
                                    width: _pillW,
                                    height: _pillH,
                                  ),
                                );
                              },
                            ),

                            // ── 4. Icon row fills full height ───────────────
                            Positioned.fill(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildTab(0),
                                        _buildTab(1),
                                      ],
                                    ),
                                  ),
                                  // Clears the notch so the icons stay
                                  // symmetric.
                                  const SizedBox(width: _notchGap),
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildTab(2),
                                        _buildTab(3),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: _CoachButton(
                onTap: widget.onCoachTap,
                size: _FloatingPillNav._coachButtonSize),
          ),
        ],
      ),
    );
  }
}

/// The single gradient pill that slides behind the nav icons.
class _SlidingPill extends StatelessWidget {
  final double width;
  final double height;

  const _SlidingPill({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// Clips the pill to a rounded rect with a circular notch at the top-center.
class _NotchedPillClipper extends CustomClipper<Path> {
  final double notchRadius;

  const _NotchedPillClipper(this.notchRadius);

  @override
  Path getClip(Size size) => _FloatingPillNav.notchedPath(size, notchRadius);

  @override
  bool shouldReclip(_NotchedPillClipper oldClipper) =>
      oldClipper.notchRadius != notchRadius;
}

/// Draws the drop shadow + soft glow following the notch outline (behind the
/// glass), so the cutout casts the right shadow instead of a plain rectangle.
class _NotchShadowPainter extends CustomPainter {
  final double notchRadius;

  const _NotchShadowPainter({required this.notchRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _FloatingPillNav.notchedPath(size, notchRadius);

    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(0, 8);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NotchShadowPainter oldDelegate) =>
      oldDelegate.notchRadius != notchRadius;
}

/// Strokes a 1px glass hairline along the notch outline (over the glass).
class _NotchBorderPainter extends CustomPainter {
  final double notchRadius;

  const _NotchBorderPainter({required this.notchRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _FloatingPillNav.notchedPath(size, notchRadius);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.20),
    );
  }

  @override
  bool shouldRepaint(_NotchBorderPainter oldDelegate) =>
      oldDelegate.notchRadius != notchRadius;
}

/// Prominent raised center action that opens the full-screen coach chat.
class _CoachButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const _CoachButton({required this.onTap, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGlow.withValues(alpha: 0.6),
              blurRadius: 16,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.chat_bubble_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

class _NavTab {
  final String path;
  final IconData icon;

  const _NavTab({
    required this.path,
    required this.icon,
  });
}
