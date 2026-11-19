import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/account/account_repository.dart';
import 'package:shop_ease_ecommerce/src/account/account_service.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:test/test.dart';

class _MemoryAccountRepository implements AccountRepository {
  _MemoryAccountRepository(this.user);

  final Map<String, dynamic> user;
  Map<String, dynamic>? settings;

  @override
  Future<Map<String, dynamic>?> findUser(ObjectId userId) async =>
      user['_id'] == userId ? user : null;

  @override
  Future<Map<String, dynamic>?> updateProfile(
    ObjectId userId,
    Map<String, Object?> updates,
    DateTime now,
  ) async {
    if (user['_id'] != userId) return null;
    if (updates.containsKey('displayName')) {
      user['displayName'] = updates['displayName'];
    }
    if (updates.containsKey('phone')) {
      final phone = updates['phone'];
      if (phone == null) {
        user.remove('phone');
      } else {
        user['phone'] = phone;
      }
    }
    user['updatedAt'] = now;
    return user;
  }

  @override
  Future<Map<String, dynamic>?> findSettings(ObjectId userId) async =>
      settings?['userId'] == userId ? settings : null;

  @override
  Future<void> saveTheme(ObjectId userId, String theme, DateTime now) async {
    settings = {
      'userId': userId,
      'theme': theme,
      'updatedAt': now,
    };
  }
}

void main() {
  late ObjectId userId;
  late _MemoryAccountRepository repository;
  late AccountService service;

  setUp(() {
    userId = ObjectId();
    repository = _MemoryAccountRepository({
      '_id': userId,
      'email': 'customer@example.test',
      'displayName': 'Customer',
      'emailVerified': true,
      'passwordHash': 'must-never-be-returned',
      'credentialVersion': 3,
    });
    service = AccountService(() async => repository);
  });

  group('AccountService profile', () {
    test('returns only safe public profile fields.', () async {
      final response = await service.getProfile(userId);
      final profile = response['user']! as Map<String, Object?>;

      expect(profile, {
        'id': userId.oid,
        'email': 'customer@example.test',
        'displayName': 'Customer',
        'emailVerified': true,
      });
      expect(profile, isNot(contains('passwordHash')));
    });

    test(
      'updates supported profile fields and permits clearing phone.',
      () async {
        final updated = await service.updateProfile(userId, {
          'displayName': '  Alex Example ',
          'phone': '+1 (555) 123-4567',
        });
        expect(
          (updated['user']! as Map<String, Object?>)['displayName'],
          'Alex Example',
        );
        expect(
          (updated['user']! as Map<String, Object?>)['phone'],
          '+1 (555) 123-4567',
        );

        final cleared = await service.updateProfile(userId, {'phone': null});
        expect(
          (cleared['user']! as Map<String, Object?>).containsKey('phone'),
          isFalse,
        );
      },
    );

    test('rejects invalid and unsupported profile updates.', () async {
      for (final body in [
        <String, Object?>{},
        {'displayName': 'x'},
        {'phone': 'not-a-phone'},
        {'email': 'new@example.test'},
      ]) {
        await expectLater(
          service.updateProfile(userId, body),
          throwsA(isA<ApiException>()),
        );
      }
    });
  });

  group('AccountService settings', () {
    test('defaults to system and persists selected theme.', () async {
      expect(
        await service.getSettings(userId),
        {
          'settings': {'theme': 'system'},
        },
      );

      expect(
        await service.updateSettings(userId, {'theme': 'dark'}),
        {
          'settings': {'theme': 'dark'},
        },
      );
      expect((await service.getSettings(userId))['settings'], {
        'theme': 'dark',
      });
      expect(repository.settings?['userId'], userId);
    });

    test('rejects unsupported settings fields and themes.', () async {
      for (final body in [
        <String, Object?>{},
        {'theme': 'sepia'},
        {'theme': 'light', 'admin': true},
      ]) {
        await expectLater(
          service.updateSettings(userId, body),
          throwsA(isA<ApiException>()),
        );
      }
    });
  });
}
