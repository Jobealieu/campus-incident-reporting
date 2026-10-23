import 'package:campus_fix/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keyboard Next moves to the next field, not the eye button', (
    tester,
  ) async {
    final first = TextEditingController();
    final second = TextEditingController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PasswordField(
                controller: first,
                textInputAction: TextInputAction.next,
              ),
              PasswordField(controller: second, label: 'Confirm password'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField).first);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final focused = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).last,
        matching: find.byType(EditableText),
      ),
    );
    expect(focused.focusNode.hasFocus, isTrue);
  });
}
