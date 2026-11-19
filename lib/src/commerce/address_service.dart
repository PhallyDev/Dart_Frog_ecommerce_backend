import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shop_ease_ecommerce/src/commerce/shop_repository.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/models/pagination.dart';

/// User-owned address book operations and input validation.
class AddressService {
  /// Creates address operations backed by the supplied repository provider.
  AddressService(this._repositoryProvider);

  final ShopRepositoryProvider _repositoryProvider;

  static const _requiredFields = {
    'recipientName',
    'line1',
    'city',
    'postalCode',
    'countryCode',
  };
  static const _allowedFields = {
    ..._requiredFields,
    'line2',
    'region',
    'phone',
    'isDefault',
  };

  /// Lists the authenticated user's address page.
  Future<Map<String, Object?>> list(
    ObjectId userId,
    Map<String, String> parameters,
  ) async {
    final pagination = _pagination(parameters, const {'page', 'limit'});
    final repository = await _repositoryProvider();
    final documents = await repository.findAddresses(
      userId,
      skip: pagination.offset,
      limit: pagination.limit,
    );
    final total = await repository.countAddresses(userId);
    return {
      'data': documents.map(_publicAddress).toList(),
      'pagination': pagination.metadata(total),
    };
  }

  /// Creates a new address owned by the authenticated user.
  Future<Map<String, Object?>> create(
    ObjectId userId,
    Map<String, Object?> body,
  ) async {
    final address = _parseBody(body, requireRequired: true);
    final repository = await _repositoryProvider();
    final id = await repository.createAddress(
      userId,
      address,
      DateTime.now().toUtc(),
    );
    final created = await repository.findAddress(userId, id);
    if (created == null) throw StateError('Created address was not readable.');
    return _publicAddress(created);
  }

  /// Updates fields of an address owned by the authenticated user.
  Future<Map<String, Object?>> update(
    ObjectId userId,
    ObjectId addressId,
    Map<String, Object?> body,
  ) async {
    final address = _parseBody(body, requireRequired: true);
    final repository = await _repositoryProvider();
    final updated = await repository.updateAddress(
      userId,
      addressId,
      address,
      DateTime.now().toUtc(),
    );
    if (!updated) _throwAddressNotFound();
    final document = await repository.findAddress(userId, addressId);
    if (document == null) _throwAddressNotFound();
    return _publicAddress(document);
  }

  /// Deletes an address owned by the authenticated user.
  Future<void> delete(ObjectId userId, ObjectId addressId) async {
    final repository = await _repositoryProvider();
    if (!await repository.deleteAddress(userId, addressId)) {
      _throwAddressNotFound();
    }
  }

  /// Marks a user-owned address as their default delivery address.
  Future<void> setDefault(ObjectId userId, ObjectId addressId) async {
    final repository = await _repositoryProvider();
    if (!await repository.setDefaultAddress(
      userId,
      addressId,
      DateTime.now().toUtc(),
    )) {
      _throwAddressNotFound();
    }
  }

  static Map<String, Object?> _parseBody(
    Map<String, Object?> body, {
    required bool requireRequired,
  }) {
    final unknown = body.keys.toSet().difference(_allowedFields);
    if (unknown.isNotEmpty) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_address',
        message: 'Unsupported address field: ${unknown.first}.',
      );
    }
    if (requireRequired) {
      final missing = _requiredFields.difference(body.keys.toSet());
      if (missing.isNotEmpty) {
        throw ApiException(
          statusCode: HttpStatus.badRequest,
          code: 'invalid_address',
          message: 'Missing required address field: ${missing.first}.',
        );
      }
    }

    final result = <String, Object?>{};
    for (final field in _requiredFields) {
      result[field] = _requiredString(body, field, maximumLength: 120);
    }
    result['line1'] = _requiredString(body, 'line1', maximumLength: 200);
    result['postalCode'] = _requiredString(
      body,
      'postalCode',
      maximumLength: 24,
    );
    final countryCode = (result['countryCode']! as String).toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) {
      _throwInvalidAddress('countryCode must be an ISO 3166-1 alpha-2 code.');
    }
    result['countryCode'] = countryCode;
    for (final field in const ['line2', 'region', 'phone']) {
      final value = body[field];
      if (value == null) {
        result[field] = null;
      } else if (value is String && value.trim().isNotEmpty) {
        final maximumLength = field == 'phone' ? 32 : 120;
        if (value.trim().length > maximumLength) {
          _throwInvalidAddress(
            '$field must not exceed $maximumLength characters.',
          );
        }
        result[field] = value.trim();
      } else {
        _throwInvalidAddress(
          '$field must be a non-empty string when supplied.',
        );
      }
    }
    final isDefault = body['isDefault'];
    if (isDefault != null && isDefault is! bool) {
      _throwInvalidAddress('isDefault must be a boolean.');
    }
    result['isDefault'] = isDefault == true;
    return result;
  }

  static String _requiredString(
    Map<String, Object?> body,
    String field, {
    required int maximumLength,
  }) {
    final value = body[field];
    if (value is! String || value.trim().isEmpty) {
      _throwInvalidAddress('$field is required.');
    }
    if (value.trim().length > maximumLength) {
      _throwInvalidAddress('$field must not exceed $maximumLength characters.');
    }
    return value.trim();
  }

  static Map<String, Object?> _publicAddress(Map<String, dynamic> document) {
    final id = document['_id'];
    final userId = document['userId'];
    final createdAt = document['createdAt'];
    final updatedAt = document['updatedAt'];
    if (id is! ObjectId ||
        userId is! ObjectId ||
        createdAt is! DateTime ||
        updatedAt is! DateTime) {
      throw StateError('Address document is invalid.');
    }
    return {
      'id': id.oid,
      'recipientName': document['recipientName'],
      'line1': document['line1'],
      if (document['line2'] is String) 'line2': document['line2'],
      'city': document['city'],
      if (document['region'] is String) 'region': document['region'],
      'postalCode': document['postalCode'],
      'countryCode': document['countryCode'],
      if (document['phone'] is String) 'phone': document['phone'],
      'isDefault': document['isDefault'] == true,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  static Pagination _pagination(
    Map<String, String> parameters,
    Set<String> supported,
  ) {
    final unknown = parameters.keys.toSet().difference(supported);
    if (unknown.isNotEmpty) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_query',
        message: 'Unsupported query parameter: ${unknown.first}.',
      );
    }
    try {
      return Pagination.parse(parameters);
    } on FormatException catch (error) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_query',
        message: error.message,
      );
    }
  }

  static Never _throwAddressNotFound() {
    throw const ApiException(
      statusCode: HttpStatus.notFound,
      code: 'address_not_found',
      message: 'Address not found.',
    );
  }

  static Never _throwInvalidAddress(String message) {
    throw ApiException(
      statusCode: HttpStatus.badRequest,
      code: 'invalid_address',
      message: message,
    );
  }
}
