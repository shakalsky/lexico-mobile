import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/study/study_bloc.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/session_toast.dart';

void main() {
  // A fresh object each time, like the bloc emits per answer; `const` would
  // hand back the same one.
  // ignore: prefer_const_constructors
  StudyToast miss() => StudyToast(message: 'miss', isPositive: false);

  Future<void> show(WidgetTester tester, StudyToast? toast) =>
      tester.pumpWidget(MaterialApp(home: SessionToast(toast: toast)));

  String picture(WidgetTester tester) =>
      (tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
              as SvgAssetLoader)
          .assetName;

  double opacity(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  testWidgets('a miss while a picture is up keeps that picture', (
    tester,
  ) async {
    await show(tester, miss());
    final first = picture(tester);

    await show(tester, miss());
    expect(picture(tester), first);
    expect(opacity(tester), 1);
  });

  testWidgets('a miss while a picture fades out shows nothing new', (
    tester,
  ) async {
    await show(tester, miss());
    final first = picture(tester);

    await show(tester, null);
    await tester.pump(const Duration(milliseconds: 100));
    await show(tester, miss());
    expect(picture(tester), first);
    expect(opacity(tester), 0);
  });

  testWidgets('once the picture is gone the next miss deals a new one', (
    tester,
  ) async {
    await show(tester, miss());
    final first = picture(tester);

    await show(tester, null);
    await tester.pumpAndSettle();
    await show(tester, miss());
    expect(picture(tester), isNot(first));
    expect(opacity(tester), 1);
  });
}
