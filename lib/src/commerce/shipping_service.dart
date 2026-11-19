import 'dart:io';

import 'package:shop_ease_ecommerce/src/commerce/shop_repository.dart';
import 'package:shop_ease_ecommerce/src/errors/api_exception.dart';
import 'package:shop_ease_ecommerce/src/models/pagination.dart';

/// Lists supported active delivery methods.
class ShippingService {
  /// Creates shipping operations backed by the supplied repository provider.
  ShippingService(this._repositoryProvider);

  final ShopRepositoryProvider _repositoryProvider;

  /// Lists active shipping methods with bounded pagination.
  Future<Map<String, Object?>> list(
    Map<String, String> parameters,
  ) async {
    final unknown = parameters.keys.toSet().difference({'page', 'limit'});
    if (unknown.isNotEmpty) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_query',
        message: 'Unsupported query parameter: ${unknown.first}.',
      );
    }
    final Pagination pagination;
    try {
      pagination = Pagination.parse(parameters);
    } on FormatException catch (error) {
      throw ApiException(
        statusCode: HttpStatus.badRequest,
        code: 'invalid_query',
        message: error.message,
      );
    }
    final repository = await _repositoryProvider();
    final documents = await repository.findShippingMethods(
      skip: pagination.offset,
      limit: pagination.limit,
    );
    final total = await repository.countShippingMethods();
    return {
      'data': documents.map(_publicShippingMethod).toList(),
      'pagination': pagination.metadata(total),
    };
  }

  /// Returns a safe public snapshot of a shipping-method document.
  static Map<String, Object?> publicShippingMethod(
    Map<String, dynamic> document,
  ) => _publicShippingMethod(document);

  static Map<String, Object?> _publicShippingMethod(
    Map<String, dynamic> document,
  ) {
    final code = document['code'];
    final name = document['name'];
    final price = document['priceMinor'];
    final currency = document['currency'];
    final minimumDays = document['minimumDeliveryDays'];
    final maximumDays = document['maximumDeliveryDays'];
    if (code is! String ||
        name is! String ||
        price is! num ||
        price < 0 ||
        price != price.toInt() ||
        currency is! String ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        minimumDays is! num ||
        maximumDays is! num ||
        minimumDays < 1 ||
        maximumDays < minimumDays ||
        minimumDays != minimumDays.toInt() ||
        maximumDays != maximumDays.toInt()) {
      throw StateError('Shipping method document is invalid.');
    }
    return {
      'code': code,
      'name': name,
      'priceMinor': price.toInt(),
      'currency': currency,
      'minimumDeliveryDays': minimumDays.toInt(),
      'maximumDeliveryDays': maximumDays.toInt(),
    };
  }
}
