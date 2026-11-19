import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/account/account_repository.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';

/// User profile and persistent preference operations.
class AccountService {
  /// Creates account operations using the supplied persistence provider.
  AccountService(this._repositoryProvider);

  static const _themes = {'light', 'dark', 'system'};
  static final _phonePattern = RegExp(r'^[+0-9][0-9() .-]{4,31}$');

  final AccountRepositoryProvider _repositoryProvider;

  /// Returns the authenticated user's safe public profile.
  Future<Map<String, Object?>> getProfile(ObjectId userId) async {
    final user = await (await _repositoryProvider()).findUser(userId);
    if (user == null) _throwProfileNotFound();
    return {'user': _publicProfile(user)};
  }

  /// Updates the supported, validated fields on the authenticated profile.
  Future<Map<String, Object?>> updateProfile(
    ObjectId userId,
    Map<String, Object?> body,
  ) async {
    const allowed = {'displayName', 'phone'};
    final unknown = body.keys.toSet().difference(allowed);
    if (unknown.isNotEmpty || body.isEmpty) _throwInvalidProfileRequest();

    final updates = <String, Object?>{};
    if (body.containsKey('displayName')) {
      updates['displayName'] = _parseDisplayName(body['displayName']);
    }
    if (body.containsKey('phone')) {
      updates['phone'] = _parsePhone(body['phone']);
    }

    final user = await (await _repositoryProvider()).updateProfile(
      userId,
      updates,
      DateTime.now().toUtc(),
    );
    if (user == null) _throwProfileNotFound();
    return {'user': _publicProfile(user)};
  }

  /// Returns stored settings, defaulting to the system theme.
  Future<Map<String, Object?>> getSettings(ObjectId userId) async {
    final settings = await (await _repositoryProvider()).findSettings(userId);
    final theme = settings?['theme'] ?? 'system';
    if (theme is! String || !_themes.contains(theme)) {
      throw StateError('Stored user theme is invalid.');
    }
    return {
      'settings': {'theme': theme},
    };
  }

  /// Validates and persists the user's light, dark, or system theme.
  Future<Map<String, Object?>> updateSettings(
    ObjectId userId,
    Map<String, Object?> body,
  ) async {
    if (body.keys.toSet().difference({'theme'}).isNotEmpty ||
        body.length != 1) {
      throw const ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_request',
        message: 'Settings updates must contain only a theme.',
      );
    }
    final theme = body['theme'];
    if (theme is! String || !_themes.contains(theme)) {
      throw const ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_theme',
        message: 'Theme must be light, dark, or system.',
      );
    }

    await (await _repositoryProvider()).saveTheme(
      userId,
      theme,
      DateTime.now().toUtc(),
    );
    return {
      'settings': {'theme': theme},
    };
  }

  static Map<String, Object?> _publicProfile(Map<String, dynamic> user) {
    final id = user['_id'];
    final email = user['email'];
    final displayName = user['displayName'];
    final emailVerified = user['emailVerified'];
    final phone = user['phone'];
    if (id is! ObjectId ||
        email is! String ||
        displayName is! String ||
        emailVerified is! bool ||
        (phone != null && phone is! String)) {
      throw StateError('User record is missing public profile fields.');
    }
    return {
      'id': id.oid,
      'email': email,
      'displayName': displayName,
      'emailVerified': emailVerified,
      if (phone is String) 'phone': phone,
    };
  }

  static String _parseDisplayName(Object? value) {
    if (value is! String) _throwInvalidProfileField('displayName');
    final displayName = value.trim();
    if (displayName.length < 2 || displayName.length > 80) {
      _throwInvalidProfileField('displayName');
    }
    return displayName;
  }

  static String? _parsePhone(Object? value) {
    if (value == null) return null;
    if (value is! String) _throwInvalidProfileField('phone');
    final phone = value.trim();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (!_phonePattern.hasMatch(phone) ||
        digits.length < 5 ||
        digits.length > 20) {
      _throwInvalidProfileField('phone');
    }
    return phone;
  }

  static Never _throwInvalidProfileField(String field) {
    throw ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_request',
      message: 'Invalid $field.',
    );
  }

  static Never _throwInvalidProfileRequest() {
    throw const ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_request',
      message: 'Profile updates must contain displayName or phone.',
    );
  }

  static Never _throwProfileNotFound() {
    throw const ApiException(
      statusCode: HttpStatus.notFound,
      code: 'profile_not_found',
      message: 'The user profile could not be found.',
    );
  }
}
