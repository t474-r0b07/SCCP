// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:sccp_command_center/core/constants/app_constants.dart';

void main() {
  test('App constants are configured', () {
    expect(AppConstants.appName, isNotEmpty);
    expect(AppConstants.supabaseUrl, startsWith('https://'));
  });
}
