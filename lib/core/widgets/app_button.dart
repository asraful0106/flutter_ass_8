import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ---------------------------------------------------------------------------
/// AppButton
///
/// Highly customizable, reusable button with:
///  • text only, or text + prefix icon and/or suffix icon
///  • filled / outlined / text variants, gradient, custom text & bg colors
///  • full shadow control (none by default)
///  • smooth loading -> success / error animation:
///      the button morphs into a circle, shows a spinner, then an animated
///      check mark (or X + shake on error), then morphs back
///  • tap prevention while loading / success / error (no double submits)
///  • active / inactive logic (+ optional callback when an inactive button
///    is tapped, e.g. to show "fill the form first")
///  • onSuccess / onError callbacks
///
/// Async usage (the button manages its own states):
///
///   AppButton(
///     text: 'Sign in',
///     onPressed: () async => await api.login(),   // throw to show error
///     onSuccess: () => context.go('/home'),
///     onError: (e, st) => showSnack(e.toString()),
///   )
///
/// Externally controlled usage (Bloc / Provider / Riverpod):
///
///   AppButton(
///     text: 'Save',
///     phase: state.isSaving ? AppButtonPhase.loading : AppButtonPhase.idle,
///     onPressed: () => bloc.add(Save()),
///   )
///
/// Requires `ScreenUtilInit` above your MaterialApp (flutter_screenutil).
/// ---------------------------------------------------------------------------

enum AppButtonVariant { filled, outlined, text }

enum AppButtonPhase { idle, loading, success, error }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.prefixIcon,
    this.suffixIcon,

    // Colors
    this.textColor,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.borderWidth,
    this.iconColor,
    this.loadingColor,
    this.successColor,
    this.errorColor,
    this.stateForegroundColor,
    this.disabledTextColor,
    this.disabledBackgroundColor,

    // Shadow (none by default)
    this.shadowColor,
    this.shadowBlurRadius,
    this.shadowSpreadRadius,
    this.shadowOffset,
    this.boxShadow,

    // Logic
    this.isActive = true,
    this.onInactiveTap,
    this.onSuccess,
    this.onError,
    this.phase,
    this.autoReset = true,
    this.minLoadingDuration = const Duration(milliseconds: 400),
    this.successDuration = const Duration(milliseconds: 1100),
    this.errorDuration = const Duration(milliseconds: 1100),

    // Look & feel
    this.fullWidth = true,
    this.width,
    this.height,
    this.borderRadius,
    this.horizontalPadding,
    this.textStyle,
    this.iconSize,
    this.iconSpacing,
    this.shrinkOnLoading = true,
    this.loadingText,
    this.successText,
    this.errorText,
    this.pressScale = 0.97,
    this.enableHaptics = false,
    this.semanticsLabel,
    this.animationDuration = const Duration(milliseconds: 380),
    this.animationCurve = Curves.easeInOutCubic,
  });

  final String text;

  /// Return a Future to get automatic loading / success / error handling.
  /// Throwing (sync or async) triggers the error state.
  final FutureOr<void> Function()? onPressed;

  final AppButtonVariant variant;
  final IconData? prefixIcon;
  final IconData? suffixIcon;

  final Color? textColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final double? borderWidth;
  final Color? iconColor;

  /// Spinner color. Defaults to the text color.
  final Color? loadingColor;
  final Color? successColor;
  final Color? errorColor;

  /// Color of the check / X mark (and text when `shrinkOnLoading` is false)
  /// on the success / error background. Defaults to white.
  final Color? stateForegroundColor;
  final Color? disabledTextColor;
  final Color? disabledBackgroundColor;

  /// Simple shadow: set `shadowColor` to enable it. No shadow by default.
  final Color? shadowColor;
  final double? shadowBlurRadius;
  final double? shadowSpreadRadius;
  final Offset? shadowOffset;

  /// Full control: a custom list of shadows (overrides the simple ones).
  final List<BoxShadow>? boxShadow;

  /// false -> greyed out, taps ignored.
  final bool isActive;

  /// Called when the user taps while the button is inactive.
  final VoidCallback? onInactiveTap;

  /// Called after the success animation has been shown.
  final VoidCallback? onSuccess;

  /// Called after the error animation has been shown.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Externally controlled phase. When non-null it overrides the internal one.
  final AppButtonPhase? phase;

  /// Return to idle automatically after success / error.
  final bool autoReset;

  /// Prevents the spinner from flashing when the request is very fast.
  final Duration minLoadingDuration;
  final Duration successDuration;
  final Duration errorDuration;

  final bool fullWidth;
  final double? width;
  final double? height;
  final double? borderRadius;
  final double? horizontalPadding;
  final TextStyle? textStyle;
  final double? iconSize;
  final double? iconSpacing;

  /// true -> the button morphs into a circle while loading / success / error.
  /// false -> it keeps its width and shows indicator + text instead.
  final bool shrinkOnLoading;
  final String? loadingText;
  final String? successText;
  final String? errorText;

  /// Scale while pressed. Use 1 to disable.
  final double pressScale;
  final bool enableHaptics;
  final String? semanticsLabel;
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  State<AppButton> createState() => AppButtonState();
}

class AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  AppButtonPhase _phase = AppButtonPhase.idle;
  bool _busy = false;
  bool _pressed = false;
  late final AnimationController _shake;

  AppButtonPhase get _effective => widget.phase ?? _phase;
  bool get _active => widget.isActive && widget.onPressed != null;

  /// Manually return to idle (useful when `autoReset` is false).
  void reset() {
    if (mounted) setState(() => _phase = AppButtonPhase.idle);
  }

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didUpdateWidget(covariant AppButton old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase && widget.phase == AppButtonPhase.error) {
      _shake.forward(from: 0);
      if (widget.enableHaptics) HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _setPhase(AppButtonPhase p) {
    if (!mounted) return;
    setState(() => _phase = p);
    if (p == AppButtonPhase.error) {
      _shake.forward(from: 0);
      if (widget.enableHaptics) HapticFeedback.heavyImpact();
    } else if (p == AppButtonPhase.success && widget.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _onTap() async {
    if (!_active) {
      widget.onInactiveTap?.call();
      return;
    }
    if (_busy || _effective != AppButtonPhase.idle) return;
    final cb = widget.onPressed;
    if (cb == null) return;
    if (widget.enableHaptics) HapticFeedback.selectionClick();

    // Externally controlled: just fire the callback.
    if (widget.phase != null) {
      cb();
      return;
    }

    _busy = true;
    final sw = Stopwatch()..start();
    Object? error;
    StackTrace? stack;
    var failed = false;
    var isAsync = false;

    try {
      final r = cb();
      if (r is Future) {
        isAsync = true;
        _setPhase(AppButtonPhase.loading);
        await r;
      }
    } catch (e, s) {
      failed = true;
      error = e;
      stack = s;
    }

    if (!mounted) {
      _busy = false;
      return;
    }

    if (isAsync) {
      final left = widget.minLoadingDuration - sw.elapsed;
      if (left > Duration.zero) await Future.delayed(left);
      if (!mounted) {
        _busy = false;
        return;
      }
    }

    if (failed) {
      _setPhase(AppButtonPhase.error);
      await Future.delayed(widget.errorDuration);
      if (!mounted) {
        _busy = false;
        return;
      }
      widget.onError?.call(error!, stack!);
      if (widget.autoReset) _setPhase(AppButtonPhase.idle);
    } else if (isAsync) {
      _setPhase(AppButtonPhase.success);
      await Future.delayed(widget.successDuration);
      if (!mounted) {
        _busy = false;
        return;
      }
      widget.onSuccess?.call();
      if (widget.autoReset) _setPhase(AppButtonPhase.idle);
    } else {
      widget.onSuccess?.call();
    }
    _busy = false;
  }

  // ---- Helpers -------------------------------------------------------------
  static Color _alpha(Color c, double o) => c.withAlpha((o * 255).round());

  static Color _contrast(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
      ? Colors.white
      : Colors.black87;

  List<BoxShadow> _shadows(bool visible) {
    final w = widget;
    if (!visible) return const [];
    if (w.boxShadow != null) return w.boxShadow!;
    if (w.shadowColor == null) return const [];
    return [
      BoxShadow(
        color: w.shadowColor!,
        blurRadius: w.shadowBlurRadius ?? 12.r,
        spreadRadius: w.shadowSpreadRadius ?? 0,
        offset: w.shadowOffset ?? Offset(0, 4.h),
      ),
    ];
  }

  // ---- Build ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = widget;
    final phase = _effective;
    final active = _active;
    final isIdle = phase == AppButtonPhase.idle;

    final h = w.height ?? 52.h;
    final radius = w.borderRadius ?? 14.r;
    final padH = w.horizontalPadding ?? 20.w;
    final collapsed = w.shrinkOnLoading && !isIdle;

    // ---- Resolve base colors per variant
    Color bg;
    Color fg;
    Color? border;
    double bw = 0;
    Gradient? gradient = w.gradient;

    switch (w.variant) {
      case AppButtonVariant.filled:
        bg = w.backgroundColor ?? cs.primary;
        fg =
            w.textColor ??
            (w.backgroundColor == null ? cs.onPrimary : _contrast(bg));
        border = w.borderColor;
        bw = border != null ? (w.borderWidth ?? 1.5.w) : 0;
        break;
      case AppButtonVariant.outlined:
        border = w.borderColor ?? cs.primary;
        fg = w.textColor ?? border;
        bg = w.backgroundColor ?? Colors.transparent;
        bw = w.borderWidth ?? 1.5.w;
        break;
      case AppButtonVariant.text:
        bg = w.backgroundColor ?? Colors.transparent;
        fg = w.textColor ?? cs.primary;
        border = w.borderColor;
        bw = border != null ? (w.borderWidth ?? 1.5.w) : 0;
        break;
    }

    final loadingFg = w.loadingColor ?? fg;
    final stateFg = w.stateForegroundColor ?? Colors.white;

    // ---- Phase / inactive overrides
    if (isIdle && !active) {
      bg =
          w.disabledBackgroundColor ??
          (w.variant == AppButtonVariant.filled
              ? _alpha(cs.onSurface, .12)
              : bg);
      fg = w.disabledTextColor ?? _alpha(cs.onSurface, .38);
      if (border != null) border = _alpha(cs.onSurface, .12);
      gradient = null;
    } else if (phase == AppButtonPhase.success) {
      bg = w.successColor ?? const Color(0xFF43A047);
      border = bw > 0 ? bg : null;
      fg = stateFg;
      gradient = null;
    } else if (phase == AppButtonPhase.error) {
      bg = w.errorColor ?? const Color(0xFFE53935);
      border = bw > 0 ? bg : null;
      fg = stateFg;
      gradient = null;
    }

    // ---- Text style & natural width
    final style = TextStyle(
      fontSize: 16.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: .2,
    ).merge(w.textStyle).copyWith(color: fg);
    final iconSz = w.iconSize ?? (style.fontSize ?? 16.sp) * 1.3;
    final gap = w.iconSpacing ?? 8.w;

    final tp = TextPainter(
      text: TextSpan(text: w.text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    var natural = tp.width + padH * 2;
    if (w.prefixIcon != null) natural += iconSz + gap;
    if (w.suffixIcon != null) natural += iconSz + gap;
    natural = math.max(natural, h);

    final tapEnabled = isIdle && !_busy && (active || w.onInactiveTap != null);

    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth.isFinite ? c.maxWidth : null;
        final expandedW =
            w.width ?? ((w.fullWidth && maxW != null) ? maxW : natural);
        final width = collapsed ? h : expandedW;

        final decoration = BoxDecoration(
          color: gradient == null ? bg : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(collapsed ? h / 2 : radius),
          border: (border != null && bw > 0)
              ? Border.all(color: border, width: bw)
              : null,
          boxShadow: _shadows(active || !isIdle),
        );

        Widget button = AnimatedContainer(
          duration: w.animationDuration,
          curve: w.animationCurve,
          width: width,
          height: h,
          decoration: decoration,
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: tapEnabled ? _onTap : null,
              onHighlightChanged: (v) {
                if (_pressed != v) setState(() => _pressed = v);
              },
              splashColor: _alpha(fg, .14),
              highlightColor: _alpha(fg, .06),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: .6, end: 1.0).animate(a),
                      child: child,
                    ),
                  ),
                  child: _content(
                    phase: phase,
                    collapsed: collapsed,
                    style: style,
                    fg: fg,
                    loadingFg: loadingFg,
                    stateFg: stateFg,
                    iconSz: iconSz,
                    gap: gap,
                    padH: padH,
                    h: h,
                  ),
                ),
              ),
            ),
          ),
        );

        button = AnimatedScale(
          scale: (_pressed && tapEnabled) ? w.pressScale : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: button,
        );

        button = AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = math.sin(t * math.pi * 5) * (1 - t) * 8.w;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: button,
        );

        return Semantics(
          button: true,
          enabled: active,
          label: w.semanticsLabel ?? w.text,
          onTap: tapEnabled ? _onTap : null,
          excludeSemantics: true,
          child: Align(heightFactor: 1, child: button),
        );
      },
    );
  }

  Widget _content({
    required AppButtonPhase phase,
    required bool collapsed,
    required TextStyle style,
    required Color fg,
    required Color loadingFg,
    required Color stateFg,
    required double iconSz,
    required double gap,
    required double padH,
    required double h,
  }) {
    final w = widget;

    Widget fit(Widget child, {double pad = 0}) => Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );

    Widget withText(Widget indicator, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        SizedBox(width: gap),
        Text(text, maxLines: 1, softWrap: false, style: style),
      ],
    );

    switch (phase) {
      case AppButtonPhase.idle:
        return fit(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (w.prefixIcon != null) ...[
                Icon(w.prefixIcon, size: iconSz, color: w.iconColor ?? fg),
                SizedBox(width: gap),
              ],
              Text(w.text, maxLines: 1, softWrap: false, style: style),
              if (w.suffixIcon != null) ...[
                SizedBox(width: gap),
                Icon(w.suffixIcon, size: iconSz, color: w.iconColor ?? fg),
              ],
            ],
          ),
          pad: padH,
        );

      case AppButtonPhase.loading:
        final spinner = SizedBox(
          width: collapsed ? h * .42 : iconSz,
          height: collapsed ? h * .42 : iconSz,
          child: CircularProgressIndicator(
            strokeWidth: 2.4.w,
            valueColor: AlwaysStoppedAnimation(loadingFg),
          ),
        );
        return KeyedSubtree(
          key: const ValueKey('loading'),
          child: collapsed
              ? spinner
              : fit(withText(spinner, w.loadingText ?? w.text), pad: padH),
        );

      case AppButtonPhase.success:
      case AppButtonPhase.error:
        final isError = phase == AppButtonPhase.error;
        final mark = _StatusMark(
          size: collapsed ? h * .46 : iconSz,
          color: stateFg,
          isError: isError,
        );
        final label = isError
            ? (w.errorText ?? w.text)
            : (w.successText ?? w.text);
        return KeyedSubtree(
          key: ValueKey(isError ? 'error' : 'success'),
          child: collapsed ? mark : fit(withText(mark, label), pad: padH),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Animated check mark / X that draws itself.
// ---------------------------------------------------------------------------
class _StatusMark extends StatelessWidget {
  const _StatusMark({
    required this.size,
    required this.color,
    required this.isError,
  });

  final double size;
  final Color color;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Transform.scale(
        scale: .8 + .2 * v,
        child: CustomPaint(
          size: Size.square(size),
          painter: _MarkPainter(
            progress: v,
            color: color,
            stroke: math.max(2.2, size * .12),
            isError: isError,
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({
    required this.progress,
    required this.color,
    required this.stroke,
    required this.isError,
  });

  final double progress, stroke;
  final Color color;
  final bool isError;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width, h = size.height;

    if (!isError) {
      final path = Path()
        ..moveTo(w * .2, h * .54)
        ..lineTo(w * .42, h * .74)
        ..lineTo(w * .8, h * .3);
      final m = path.computeMetrics().first;
      canvas.drawPath(m.extractPath(0, m.length * progress), p);
    } else {
      final a0 = Offset(w * .25, h * .25), a1 = Offset(w * .75, h * .75);
      final b0 = Offset(w * .75, h * .25), b1 = Offset(w * .25, h * .75);
      final p1 = (progress * 2).clamp(0.0, 1.0);
      final p2 = ((progress - .5) * 2).clamp(0.0, 1.0);
      canvas.drawLine(a0, Offset.lerp(a0, a1, p1)!, p);
      if (p2 > 0) canvas.drawLine(b0, Offset.lerp(b0, b1, p2)!, p);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter o) =>
      o.progress != progress ||
      o.color != color ||
      o.stroke != stroke ||
      o.isError != isError;
}
