import 'package:flutter/material.dart';

import 'palette.dart';

/// Semantic colors beyond [ColorScheme] (SPEC §9).
///
/// `*Container` colors are fills (e.g. the rest timer bar); the plain color is
/// the tone for text and icons on the normal background.
@immutable
class GymColors extends ThemeExtension<GymColors> {
  const GymColors({
    required this.action,
    required this.onAction,
    required this.activeEdge,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.rest,
    required this.restContainer,
    required this.onRestContainer,
    required this.record,
    required this.recordContainer,
    required this.onRecordContainer,
  });

  /// Fill of primary actions ("Training starten", "Satz speichern").
  final Color action;
  final Color onAction;

  /// 4 dp left edge of the active exercise tile.
  final Color activeEdge;

  /// Done, "Pause vorbei". Text on [successContainer] must be large or bold
  /// (contrast 4.25:1, see PROGRESS.md "Annahmen").
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  /// Rest timer, hints.
  final Color rest;
  final Color restContainer;
  final Color onRestContainer;

  /// Records (destructive actions use [ColorScheme.error]).
  final Color record;
  final Color recordContainer;
  final Color onRecordContainer;

  static const light = GymColors(
    action: Palette.plateBlue,
    onAction: Palette.white,
    activeEdge: Palette.plateBlue,
    success: Palette.greenDeep,
    successContainer: Palette.plateGreen,
    onSuccessContainer: Palette.white,
    rest: Palette.ochre,
    restContainer: Palette.plateYellow,
    onRestContainer: Palette.iron,
    record: Palette.plateRed,
    recordContainer: Palette.plateRed,
    onRecordContainer: Palette.white,
  );

  static const dark = GymColors(
    action: Palette.plateBlue,
    onAction: Palette.white,
    activeEdge: Palette.blueLight,
    success: Palette.greenLight,
    successContainer: Palette.plateGreen,
    onSuccessContainer: Palette.white,
    rest: Palette.plateYellow,
    restContainer: Palette.plateYellow,
    onRestContainer: Palette.iron,
    record: Palette.redLight,
    recordContainer: Palette.plateRed,
    onRecordContainer: Palette.white,
  );

  /// The [GymColors] of the current theme.
  static GymColors of(BuildContext context) =>
      Theme.of(context).extension<GymColors>()!;

  @override
  GymColors copyWith({
    Color? action,
    Color? onAction,
    Color? activeEdge,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? rest,
    Color? restContainer,
    Color? onRestContainer,
    Color? record,
    Color? recordContainer,
    Color? onRecordContainer,
  }) {
    return GymColors(
      action: action ?? this.action,
      onAction: onAction ?? this.onAction,
      activeEdge: activeEdge ?? this.activeEdge,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      rest: rest ?? this.rest,
      restContainer: restContainer ?? this.restContainer,
      onRestContainer: onRestContainer ?? this.onRestContainer,
      record: record ?? this.record,
      recordContainer: recordContainer ?? this.recordContainer,
      onRecordContainer: onRecordContainer ?? this.onRecordContainer,
    );
  }

  @override
  GymColors lerp(GymColors? other, double t) {
    if (other == null) return this;
    return GymColors(
      action: Color.lerp(action, other.action, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      activeEdge: Color.lerp(activeEdge, other.activeEdge, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      rest: Color.lerp(rest, other.rest, t)!,
      restContainer: Color.lerp(restContainer, other.restContainer, t)!,
      onRestContainer: Color.lerp(onRestContainer, other.onRestContainer, t)!,
      record: Color.lerp(record, other.record, t)!,
      recordContainer: Color.lerp(recordContainer, other.recordContainer, t)!,
      onRecordContainer: Color.lerp(
        onRecordContainer,
        other.onRecordContainer,
        t,
      )!,
    );
  }
}
