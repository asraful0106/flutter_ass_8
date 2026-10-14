import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ---------------------------------------------------------------------------
/// AppInputField
///
/// Highly customizable, reusable input with:
///  • floating label that sits ON the border (vertically centered to it,
///    with a notch cut into the border) and animates smoothly
///  • label text or icon + text
///  • idle / focus / error colors for label, border and background
///  • regex validation (+ hint & error message), required, custom validator
///  • API error (`errorText`) that always wins over local validation
///  • password eye toggle + regex-based strength meter (can be turned off)
///  • clear button, prefix icon, custom suffix, counter, helper text
///
/// Requires `ScreenUtilInit` above your MaterialApp (flutter_screenutil).
/// The field needs a bounded width (e.g. inside a Column / Expanded).
/// Leave ~10.h above the first field so the floating label isn't clipped.
///
/// Form usage:
///   final emailKey = GlobalKey<AppInputFieldState>();
///   AppInputField(key: emailKey, label: 'Email', type: AppInputType.email);
///   if (emailKey.currentState!.validate()) { ... }
/// ---------------------------------------------------------------------------

enum AppInputType { text, name, email, password, number, phone, url, multiline }

class PasswordRule {
  const PasswordRule(this.pattern, this.hint);

  /// Rule passes when this pattern has a match in the password.
  final RegExp pattern;

  /// Used in the suggestion: "Add $hint".
  final String hint;
}

final List<PasswordRule> kDefaultPasswordRules = [
  PasswordRule(RegExp(r'.{8,}'), 'at least 8 characters'),
  PasswordRule(RegExp(r'[a-z]'), 'a lowercase letter'),
  PasswordRule(RegExp(r'[A-Z]'), 'an uppercase letter'),
  PasswordRule(RegExp(r'\d'), 'a number'),
  PasswordRule(RegExp(r'[^A-Za-z0-9]'), 'a special character'),
];

class AppInputField extends StatefulWidget {
  const AppInputField({
    super.key,
    required this.label,
    this.type = AppInputType.text,
    this.labelIcon,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.hintText,
    this.helperText,

    // Colors (fall back to Theme colorScheme)
    this.labelColor,
    this.focusedLabelColor,
    this.errorLabelColor,
    this.borderColor,
    this.focusedBorderColor,
    this.errorBorderColor,
    this.backgroundColor,
    this.focusedBackgroundColor,
    this.errorBackgroundColor,
    this.textColor,
    this.hintColor,

    // Validation
    this.regex,
    this.regexHint,
    this.regexError,
    this.isRequired = false,
    this.requiredError,
    this.showRequiredMark = false,
    this.validator,
    this.errorText,

    // Password
    this.showPasswordStrength = true,
    this.passwordRules,
    this.strengthColors,
    this.strengthLabels,

    // Extras
    this.prefixIcon,
    this.suffix,
    this.showClearButton = true,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.unfocusOnTapOutside = true,
    this.maxLength,
    this.maxLines,
    this.minLines,
    this.showCounter = true,
    this.textInputAction,
    this.inputFormatters,
    this.textCapitalization,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.onTap,

    // Sizing & motion
    this.borderRadius,
    this.borderWidth,
    this.focusedBorderWidth,
    this.fieldHeight,
    this.labelFontSize,
    this.textFontSize,
    this.floatingLabelScale = 0.82,
    this.animationDuration = const Duration(milliseconds: 260),
  });

  final String label;
  final AppInputType type;

  /// When set, the label shows icon + text.
  final IconData? labelIcon;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? initialValue;

  /// Shown only while the label is floating (focused / has text).
  final String? hintText;
  final String? helperText;

  final Color? labelColor, focusedLabelColor, errorLabelColor;
  final Color? borderColor, focusedBorderColor, errorBorderColor;
  final Color? backgroundColor, focusedBackgroundColor, errorBackgroundColor;
  final Color? textColor, hintColor;

  /// Anchor your pattern (^...$) for full-match behavior.
  final RegExp? regex;

  /// Shown under the field while it is focused and has no error.
  final String? regexHint;
  final String? regexError;
  final bool isRequired;
  final String? requiredError;
  final bool showRequiredMark;

  /// Extra validation after the regex. Return an error message or null.
  final String? Function(String value)? validator;

  /// Error coming from your API. Takes priority; set to null to clear it
  /// (e.g. inside onChanged).
  final String? errorText;

  final bool showPasswordStrength;
  final List<PasswordRule>? passwordRules;

  /// 4 colors: weak, fair, good, strong.
  final List<Color>? strengthColors;

  /// 4 labels: weak, fair, good, strong.
  final List<String>? strengthLabels;

  final IconData? prefixIcon;
  final Widget? suffix;
  final bool showClearButton;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;

  /// Removes focus (and closes the keyboard) when tapping outside the field.
  final bool unfocusOnTapOutside;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final bool showCounter;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization? textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  final double? borderRadius;
  final double? borderWidth;
  final double? focusedBorderWidth;
  final double? fieldHeight;
  final double? labelFontSize;
  final double? textFontSize;
  final double floatingLabelScale;
  final Duration animationDuration;

  @override
  State<AppInputField> createState() => AppInputFieldState();
}

class AppInputFieldState extends State<AppInputField>
    with SingleTickerProviderStateMixin {
  late TextEditingController _ctrl;
  late FocusNode _focus;
  bool _ownsCtrl = false;
  bool _ownsFocus = false;

  late final AnimationController _ac;
  late final CurvedAnimation _anim;

  bool _touched = false;
  bool _obscure = true;

  // Shared by the TextField and the whole field area (label, clear/eye
  // buttons, padding) so taps on those count as "inside" the field.
  final Object _tapGroup = Object();

  // Cached label measurement
  String? _mKey;
  double _mW = 0, _mH = 0;

  bool get _isPassword => widget.type == AppInputType.password;
  bool get _isMultiline =>
      widget.type == AppInputType.multiline || (widget.maxLines ?? 1) > 1;
  bool get _shouldFloat => _focus.hasFocus || _ctrl.text.isNotEmpty;

  // ---- Public API ----------------------------------------------------------
  String get text => _ctrl.text;

  bool validate() {
    setState(() => _touched = true);
    return _localError(_ctrl.text) == null &&
        (widget.errorText == null || widget.errorText!.isEmpty);
  }

  bool get isValid => _localError(_ctrl.text) == null;
  void focus() => _focus.requestFocus();
  void clear() {
    _ctrl.clear();
    widget.onChanged?.call('');
  }

  // ---- Lifecycle -----------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _ctrl =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _ownsCtrl = widget.controller == null;
    _focus = widget.focusNode ?? FocusNode();
    _ownsFocus = widget.focusNode == null;

    _ac = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: _shouldFloat ? 1 : 0,
    );
    _anim = CurvedAnimation(
      parent: _ac,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _ctrl.addListener(_onChanged);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant AppInputField old) {
    super.didUpdateWidget(old);
    _ac.duration = widget.animationDuration;
    if (old.controller != widget.controller) {
      _ctrl.removeListener(_onChanged);
      if (_ownsCtrl) _ctrl.dispose();
      _ctrl =
          widget.controller ?? TextEditingController(text: widget.initialValue);
      _ownsCtrl = widget.controller == null;
      _ctrl.addListener(_onChanged);
      _sync();
    }
    if (old.focusNode != widget.focusNode) {
      _focus.removeListener(_onFocus);
      if (_ownsFocus) _focus.dispose();
      _focus = widget.focusNode ?? FocusNode();
      _ownsFocus = widget.focusNode == null;
      _focus.addListener(_onFocus);
      _sync();
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _focus.removeListener(_onFocus);
    if (_ownsCtrl) _ctrl.dispose();
    if (_ownsFocus) _focus.dispose();
    _anim.dispose();
    _ac.dispose();
    super.dispose();
  }

  void _onChanged() {
    _sync();
    if (mounted) setState(() {});
  }

  void _onFocus() {
    if (!_focus.hasFocus) _touched = true;
    _sync();
    if (mounted) setState(() {});
  }

  void _sync() => _shouldFloat ? _ac.forward() : _ac.reverse();

  // ---- Validation ----------------------------------------------------------
  RegExp? get _regex {
    if (widget.regex != null) return widget.regex;
    switch (widget.type) {
      case AppInputType.email:
        return RegExp(
          r'^[\w.+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
        );
      case AppInputType.phone:
        return RegExp(r'^\+?[0-9\s\-()]{7,15}$');
      case AppInputType.url:
        return RegExp(r'^(https?:\/\/)?([\w\-]+\.)+[\w\-]{2,}(\/\S*)?$');
      default:
        return null;
    }
  }

  String get _regexErrorText {
    if (widget.regexError != null) return widget.regexError!;
    switch (widget.type) {
      case AppInputType.email:
        return 'Enter a valid email address';
      case AppInputType.phone:
        return 'Enter a valid phone number';
      case AppInputType.url:
        return 'Enter a valid URL';
      default:
        return 'Invalid format';
    }
  }

  String? _localError(String v) {
    if (v.isEmpty) {
      return widget.isRequired
          ? (widget.requiredError ?? '${widget.label} is required')
          : null;
    }
    final r = _regex;
    if (r != null && !r.hasMatch(v)) return _regexErrorText;
    return widget.validator?.call(v);
  }

  String? get _currentError {
    final api = widget.errorText;
    if (api != null && api.isNotEmpty) return api;
    if (!_touched) return null;
    return _localError(_ctrl.text);
  }

  // ---- Password strength ---------------------------------------------------
  _Strength _strength() {
    final rules = widget.passwordRules ?? kDefaultPasswordRules;
    final pwd = _ctrl.text;
    PasswordRule? missing;
    var passed = 0;
    for (final r in rules) {
      if (r.pattern.hasMatch(pwd)) {
        passed++;
      } else {
        missing ??= r;
      }
    }
    final ratio = rules.isEmpty ? 1.0 : passed / rules.length;
    final level = ratio <= 0.4 ? 1 : (ratio <= 0.6 ? 2 : (ratio < 1 ? 3 : 4));
    return _Strength(level, missing);
  }

  // ---- Helpers -------------------------------------------------------------
  static Color _alpha(Color c, double o) => c.withAlpha((o * 255).round());

  void _measure(
    String text,
    TextStyle style,
    double iconW,
    TextScaler scaler,
    TextDirection dir,
  ) {
    final key = '$text|${style.fontSize}|$iconW|${scaler.scale(10)}';
    if (key == _mKey) return;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: dir,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    _mKey = key;
    _mW = tp.width + iconW;
    _mH = tp.height;
  }

  // ---- Build ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final error = _currentError;
    final hasError = error != null;
    final focused = _focus.hasFocus;
    final w = widget;

    final errC = w.errorBorderColor ?? cs.error;
    final bg = w.backgroundColor ?? cs.surface;
    final target = _Visual(
      border: !w.enabled
          ? _alpha(w.borderColor ?? cs.outlineVariant, .6)
          : hasError
          ? errC
          : focused
          ? (w.focusedBorderColor ?? cs.primary)
          : (w.borderColor ?? cs.outlineVariant),
      fill: hasError
          ? (w.errorBackgroundColor ?? _alpha(errC, .06))
          : focused
          ? (w.focusedBackgroundColor ?? bg)
          : bg,
      label: hasError
          ? (w.errorLabelColor ?? cs.error)
          : focused
          ? (w.focusedLabelColor ?? cs.primary)
          : (w.labelColor ?? cs.onSurfaceVariant),
      borderWidth: (focused || hasError)
          ? (w.focusedBorderWidth ?? 1.6.w)
          : (w.borderWidth ?? 1.w),
    );

    return Opacity(
      opacity: w.enabled ? 1 : .55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<_Visual>(
            tween: _VisualTween(end: target),
            duration: w.animationDuration,
            curve: Curves.easeOut,
            builder: (context, v, _) => AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => _buildField(context, cs, v, _anim.value),
            ),
          ),
          _buildFooter(cs, error, errC),
        ],
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    ColorScheme cs,
    _Visual v,
    double t,
  ) {
    final w = widget;
    final padH = 14.w, padV = 16.h;
    final radius = w.borderRadius ?? 12.r;
    final textSize = w.textFontSize ?? 15.sp;
    final lblSize = w.labelFontSize ?? 14.sp;
    final iconSz = lblSize * 1.15;
    final prefixSz = 20.sp;
    final multiline = _isMultiline;

    final labelText =
        w.label + (w.isRequired && w.showRequiredMark ? ' *' : '');
    final labelStyle = TextStyle(
      fontSize: lblSize,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    final iconW = w.labelIcon != null ? iconSz + 6.w : 0.0;
    _measure(
      labelText,
      labelStyle,
      iconW,
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
    );
    final labelH = math.max(_mH, iconSz);

    final showClear =
        w.showClearButton &&
        !_isPassword &&
        !w.readOnly &&
        w.enabled &&
        _focus.hasFocus &&
        _ctrl.text.isNotEmpty;
    final hasSuffix = _isPassword || w.suffix != null || showClear;

    final prefixW = w.prefixIcon != null ? prefixSz + 10.w : 0.0;
    final restLeft = padH + prefixW;
    final floatLeft = math.max(14.w, radius + 6.w);
    final gapPad = 4.w;

    return TapRegion(
      groupId: _tapGroup,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: w.enabled ? _focus.requestFocus : null,
        child: LayoutBuilder(
          builder: (context, c) {
            final maxW = math.max(
              0.0,
              c.maxWidth - restLeft - padH - (hasSuffix ? 44.w : 0),
            );
            final labelW = math.min(_mW, maxW);
            final gapW = (labelW * w.floatingLabelScale + gapPad * 2) * t;

            final left = lerpDouble(restLeft, floatLeft, t)!;
            final dy = lerpDouble(multiline ? padV : 0, -labelH / 2, t)!;
            final scale = lerpDouble(1, w.floatingLabelScale, t)!;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Background + notched border
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FieldPainter(
                      fill: v.fill,
                      border: v.border,
                      borderWidth: v.borderWidth,
                      radius: radius,
                      gapStart: floatLeft - gapPad,
                      gapWidth: gapW,
                    ),
                  ),
                ),

                // Input row
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: w.fieldHeight ?? 56.h),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: padH,
                      right: hasSuffix ? 4.w : padH,
                    ),
                    child: Row(
                      crossAxisAlignment: multiline
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        if (w.prefixIcon != null)
                          Padding(
                            padding: EdgeInsets.only(
                              right: 10.w,
                              top: multiline ? padV : 0,
                            ),
                            child: Icon(
                              w.prefixIcon,
                              size: prefixSz,
                              color: v.label,
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: padV),
                            child: _buildTextField(cs, v, t, textSize),
                          ),
                        ),
                        if (showClear) _clearButton(v),
                        if (_isPassword) _eyeButton(v),
                        if (w.suffix != null) w.suffix!,
                      ],
                    ),
                  ),
                ),

                // Floating label
                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment(-1, multiline ? -1 : -t),
                      child: Transform.translate(
                        offset: Offset(left, dy),
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxW),
                            child: SizedBox(
                              height: labelH,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (w.labelIcon != null) ...[
                                    Icon(
                                      w.labelIcon,
                                      size: iconSz,
                                      color: v.label,
                                    ),
                                    SizedBox(width: 6.w),
                                  ],
                                  Flexible(
                                    child: Text(
                                      labelText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: labelStyle.copyWith(
                                        color: v.label,
                                      ),
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField(ColorScheme cs, _Visual v, double t, double textSize) {
    final w = widget;
    final isNumber = w.type == AppInputType.number;
    final isPhone = w.type == AppInputType.phone;

    final keyboard = switch (w.type) {
      AppInputType.email => TextInputType.emailAddress,
      AppInputType.password => TextInputType.visiblePassword,
      AppInputType.number => const TextInputType.numberWithOptions(
        decimal: true,
      ),
      AppInputType.phone => TextInputType.phone,
      AppInputType.url => TextInputType.url,
      AppInputType.multiline => TextInputType.multiline,
      AppInputType.name => TextInputType.name,
      AppInputType.text => TextInputType.text,
    };

    final hint = _alpha(w.hintColor ?? cs.onSurfaceVariant, .6 * t);

    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      enabled: w.enabled,
      readOnly: w.readOnly,
      autofocus: w.autofocus,
      obscureText: _isPassword && _obscure,
      keyboardType: keyboard,
      textInputAction:
          w.textInputAction ??
          (_isMultiline ? TextInputAction.newline : TextInputAction.next),
      textCapitalization:
          w.textCapitalization ??
          (w.type == AppInputType.name
              ? TextCapitalization.words
              : TextCapitalization.none),
      autocorrect: !(_isPassword || w.type == AppInputType.email),
      enableSuggestions: !_isPassword,
      autofillHints:
          w.autofillHints ??
          switch (w.type) {
            AppInputType.email => const [AutofillHints.email],
            AppInputType.password => const [AutofillHints.password],
            AppInputType.phone => const [AutofillHints.telephoneNumber],
            AppInputType.name => const [AutofillHints.name],
            _ => null,
          },
      inputFormatters: [
        if (isNumber) FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        if (isPhone) FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
        ...?w.inputFormatters,
      ],
      maxLength: w.maxLength,
      maxLines: _isPassword ? 1 : (_isMultiline ? (w.maxLines ?? 4) : 1),
      minLines: _isMultiline ? (w.minLines ?? 3) : 1,
      cursorColor: v.border,
      style: TextStyle(
        fontSize: textSize,
        color: w.textColor ?? cs.onSurface,
        height: 1.25,
      ),
      onChanged: w.onChanged,
      onSubmitted: w.onSubmitted,
      onTap: w.onTap,
      groupId: _tapGroup,
      onTapOutside: w.unfocusOnTapOutside ? (_) => _focus.unfocus() : null,
      decoration: InputDecoration(
        isCollapsed: true,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        counterText: '',
        hintText: w.hintText,
        hintStyle: TextStyle(fontSize: textSize, color: hint),
      ),
    );
  }

  Widget _eyeButton(_Visual v) => IconButton(
    onPressed: () => setState(() => _obscure = !_obscure),
    tooltip: _obscure ? 'Show password' : 'Hide password',
    splashRadius: 18.r,
    padding: EdgeInsets.all(8.r),
    constraints: const BoxConstraints(),
    icon: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, a) => ScaleTransition(
        scale: a,
        child: FadeTransition(opacity: a, child: child),
      ),
      child: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        key: ValueKey(_obscure),
        size: 20.sp,
        color: v.label,
      ),
    ),
  );

  Widget _clearButton(_Visual v) => IconButton(
    onPressed: clear,
    tooltip: 'Clear',
    splashRadius: 16.r,
    padding: EdgeInsets.all(8.r),
    constraints: const BoxConstraints(),
    icon: Icon(Icons.cancel_rounded, size: 18.sp, color: _alpha(v.label, .7)),
  );

  Widget _buildFooter(ColorScheme cs, String? error, Color errC) {
    final w = widget;
    final muted = w.hintColor ?? cs.onSurfaceVariant;
    final focused = _focus.hasFocus;

    final helper = (focused && w.regexHint != null)
        ? w.regexHint
        : w.helperText;
    final hasMessage = error != null || (helper != null && helper.isNotEmpty);
    final showCounter = w.showCounter && w.maxLength != null;
    final showStrength =
        _isPassword && w.showPasswordStrength && _ctrl.text.isNotEmpty;
    final hasContent = hasMessage || showCounter || showStrength;

    Widget message() {
      if (error != null) {
        return _message(error, errC, icon: Icons.error_outline_rounded);
      }
      if (helper != null && helper.isNotEmpty) {
        return _message(helper, muted);
      }
      return const SizedBox.shrink(key: ValueKey('none'));
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !hasContent
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.only(top: 6.h, left: 4.w, right: 4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showStrength) ...[
                    Builder(
                      builder: (_) {
                        final s = _strength();
                        return _StrengthMeter(
                          level: s.level,
                          colors: w.strengthColors ?? _defaultStrengthColors,
                          labels: w.strengthLabels ?? _defaultStrengthLabels,
                          trackColor: _alpha(muted, .2),
                          suggestion: s.level < 4 ? s.missing?.hint : null,
                          mutedColor: muted,
                        );
                      },
                    ),
                    SizedBox(height: hasMessage ? 6.h : 0),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Semantics(
                          liveRegion: error != null,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            switchInCurve: Curves.easeOutCubic,
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(
                                  begin: const Offset(0, -.25),
                                  end: Offset.zero,
                                ).animate(a),
                                child: child,
                              ),
                            ),
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.topLeft,
                              children: [
                                ...previous,
                                if (current != null) current,
                              ],
                            ),
                            child: message(),
                          ),
                        ),
                      ),
                      if (showCounter)
                        Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: Text(
                            '${_ctrl.text.length}/${w.maxLength}',
                            style: TextStyle(fontSize: 12.sp, color: muted),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _message(String text, Color color, {IconData? icon}) => Row(
    key: ValueKey(text),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null) ...[
        Padding(
          padding: EdgeInsets.only(top: 1.h),
          child: Icon(icon, size: 14.sp, color: color),
        ),
        SizedBox(width: 4.w),
      ],
      Expanded(
        child: Text(
          text,
          style: TextStyle(fontSize: 12.sp, height: 1.3, color: color),
        ),
      ),
    ],
  );
}

const _defaultStrengthColors = [
  Color(0xFFE53935),
  Color(0xFFFB8C00),
  Color(0xFFFFB300),
  Color(0xFF43A047),
];
const _defaultStrengthLabels = ['Weak', 'Fair', 'Good', 'Strong'];

class _Strength {
  const _Strength(this.level, this.missing);
  final int level; // 1..4
  final PasswordRule? missing;
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({
    required this.level,
    required this.colors,
    required this.labels,
    required this.trackColor,
    required this.mutedColor,
    this.suggestion,
  });

  final int level;
  final List<Color> colors;
  final List<String> labels;
  final Color trackColor;
  final Color mutedColor;
  final String? suggestion;

  @override
  Widget build(BuildContext context) {
    final color = colors[(level - 1).clamp(0, colors.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      height: 4.h,
                      margin: EdgeInsets.only(right: i < 3 ? 4.w : 0),
                      decoration: BoxDecoration(
                        color: i < level ? color : trackColor,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(width: 10.w),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              child: Text(labels[(level - 1).clamp(0, labels.length - 1)]),
            ),
          ],
        ),
        if (suggestion != null)
          Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Text(
              'Add $suggestion',
              style: TextStyle(fontSize: 11.sp, color: mutedColor),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Animated visual state (border / fill / label color + border width)
// ---------------------------------------------------------------------------
@immutable
class _Visual {
  const _Visual({
    required this.border,
    required this.fill,
    required this.label,
    required this.borderWidth,
  });

  final Color border, fill, label;
  final double borderWidth;

  static _Visual lerp(_Visual a, _Visual b, double t) => _Visual(
    border: Color.lerp(a.border, b.border, t)!,
    fill: Color.lerp(a.fill, b.fill, t)!,
    label: Color.lerp(a.label, b.label, t)!,
    borderWidth: lerpDouble(a.borderWidth, b.borderWidth, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is _Visual &&
      other.border == border &&
      other.fill == fill &&
      other.label == label &&
      other.borderWidth == borderWidth;

  @override
  int get hashCode => Object.hash(border, fill, label, borderWidth);
}

class _VisualTween extends Tween<_Visual> {
  // ignore: unused_element_parameter
  _VisualTween({super.begin, super.end});

  @override
  _Visual lerp(double t) => _Visual.lerp(begin!, end!, t);
}

// ---------------------------------------------------------------------------
// Paints the fill + rounded border with a notch where the label sits.
// ---------------------------------------------------------------------------
class _FieldPainter extends CustomPainter {
  _FieldPainter({
    required this.fill,
    required this.border,
    required this.borderWidth,
    required this.radius,
    required this.gapStart,
    required this.gapWidth,
  });

  final Color fill, border;
  final double borderWidth, radius, gapStart, gapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(outer, Paint()..color = fill);

    canvas.save();
    if (gapWidth > 0.5) {
      final all = Path()
        ..addRect(Rect.fromLTWH(-20, -20, size.width + 40, size.height + 40));
      final gap = Path()
        ..addRect(
          Rect.fromLTWH(
            gapStart,
            -borderWidth * 2 - 2,
            gapWidth,
            borderWidth * 4 + 4,
          ),
        );
      canvas.clipPath(Path.combine(PathOperation.difference, all, gap));
    }
    canvas.drawRRect(
      outer.deflate(borderWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..color = border
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FieldPainter o) =>
      o.fill != fill ||
      o.border != border ||
      o.borderWidth != borderWidth ||
      o.radius != radius ||
      o.gapStart != gapStart ||
      o.gapWidth != gapWidth;
}
