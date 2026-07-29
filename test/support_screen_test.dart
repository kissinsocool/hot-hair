import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_hair_app/features/salon_discovery/presentation/support_screen.dart';

void main() {
  testWidgets('support form validates and submits', (tester) async {
    String? submittedProblem;
    String? submittedContact;
    await tester.pumpWidget(
      MaterialApp(
        home: SupportScreen(
          onSubmit: (problem, contact) async {
            submittedProblem = problem;
            submittedContact = contact;
          },
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, '提交'));
    await tester.pump();
    expect(find.text('请描述您遇到的问题'), findsNWidgets(2));
    expect(find.text('请输入联系方式'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '服务过程中被强迫充值');
    await tester.enterText(fields.at(1), '13800138000');
    await tester.tap(find.widgetWithText(ElevatedButton, '提交'));
    await tester.pumpAndSettle();

    expect(find.text('反馈已提交，我们会尽快与您联系'), findsOneWidget);
    expect(submittedProblem, '服务过程中被强迫充值');
    expect(submittedContact, '13800138000');
    expect(find.text('服务过程中被强迫充值'), findsNothing);
    expect(find.text('13800138000'), findsNothing);
  });
}
