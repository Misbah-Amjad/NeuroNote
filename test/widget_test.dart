import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuronote/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isLoggedIn returns false when not logged in', () async {
    SharedPreferences.setMockInitialValues({});
    final loggedIn = await AuthService.isLoggedIn();
    expect(loggedIn, isFalse);
  });
}
