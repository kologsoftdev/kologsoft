import 'package:flutter_test/flutter_test.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:kologsoft/screens/role_access_config.dart';

void main() {
  group('role access config', () {
    test('buildRoleAccessActions uses custom selections for sales manager', () {
      final actions = buildRoleAccessActions(
        'Sales Manager',
        roleSelections: {
          'salesmanager': [Routes.sales, Routes.stockrequest],
        },
      );

      expect(actions.map((action) => action.route).toList(), [Routes.sales, Routes.stockrequest]);
      expect(actions.first.title, 'Sales');
    });

    test('normalizeRoleKey handles spaces and mixed casing', () {
      expect(normalizeRoleKey('Sales Attendance'), 'salesattendance');
      expect(normalizeRoleKey('Operations Officer '), 'operationsofficer');
    });
  });
}
