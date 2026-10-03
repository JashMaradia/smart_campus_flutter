import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';

void main() {
  testWidgets('EmptyState shows its title and message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EmptyState(
            icon: Icons.inbox_outlined, title: 'Nothing here', message: 'Add something'),
      ),
    ));
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Add something'), findsOneWidget);
  });

  testWidgets('Login style form shows validation errors', (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: key,
          child: Column(
            children: [
              const AppTextField(label: 'Email / Student ID', validator: Validators.loginId),
              PasswordField(controller: TextEditingController(), validator: Validators.password),
            ],
          ),
        ),
      ),
    ));
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Email or Student ID is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });
}
