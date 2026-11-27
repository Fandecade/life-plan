import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/theme/app_theme.dart';
import 'package:life_planner/core/widgets/app_button.dart';
import 'package:life_planner/core/widgets/text_input_dialog.dart';

void main() {
  testWidgets('输入对话框关闭后不抛 controller 已释放异常', (
    WidgetTester tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: AppGhostButton(
                label: '打开',
                onPressed: () async {
                  result = await showTextInputDialog(
                    context,
                    title: '倒计时标题',
                    initial: '初始标题',
                    hintText: '例如：项目截止',
                    validate: (String value) =>
                        value.isEmpty ? '请输入标题' : null,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('倒计时标题'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '新标题');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, '新标题');
    expect(tester.takeException(), isNull);
  });

  testWidgets('数字输入对话框校验失败时停留在对话框', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: AppGhostButton(
                label: '打开',
                onPressed: () => showTextInputDialog(
                  context,
                  title: '自定义提前量',
                  initial: '10',
                  keyboardType: TextInputType.number,
                  digitsOnly: true,
                  validate: (String value) {
                    final int? minutes = int.tryParse(value);
                    return minutes == null ? '请输入数字' : null;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}