import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();
  static const _tokenKey = 'economarket_auth_token';
  static const _userIdKey = 'economarket_auth_user_id';
  static const _userNameKey = 'economarket_auth_user_name';
  static const _userEmailKey = 'economarket_auth_user_email';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  final http.Client _http = http.Client();
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final ValueNotifier<int> shoppingListRevision = ValueNotifier<int>(0);
  String? _token;
  UserProfile? currentUser;
  int? activeShoppingListId;
  Future<ShoppingList>? _ensuringActiveList;

  String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/$'), '');
    }
    if (kIsWeb) return 'http://localhost:3000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  bool get isAuthenticated => _token != null && currentUser != null;

  Future<UserProfile?> restoreSession() async {
    _token = await _preferences.getString(_tokenKey);
    if (_token == null || _token!.isEmpty) return null;

    try {
      final json = await _requestMap('GET', '/auth/me', authenticated: true);
      currentUser = UserProfile.fromJson(json);
      activeShoppingListId = await _preferences.getInt(
        'economarket_active_list_${currentUser!.id}',
      );
      await _storeUser(currentUser!);
      return currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile> login(String email, String password) async {
    final json = await _requestMap(
      'POST',
      '/auth/login',
      body: {'email': email, 'senha': password},
    );
    return _acceptAuthentication(json);
  }

  Future<UserProfile> loginWithFirebase({
    required String idToken,
    String? name,
  }) async {
    final body = <String, dynamic>{'idToken': idToken};
    final normalizedName = name?.trim();
    if (normalizedName != null && normalizedName.isNotEmpty) {
      body['nome'] = normalizedName;
    }
    final json = await _requestMap('POST', '/auth/firebase', body: body);
    return _acceptAuthentication(json);
  }

  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final json = await _requestMap(
      'POST',
      '/auth/registrar',
      body: {'nome': name, 'email': email, 'senha': password},
    );
    return _acceptAuthentication(json);
  }

  Future<UserProfile> _acceptAuthentication(Map<String, dynamic> json) async {
    final token = json['token'] as String?;
    final userJson = json['usuario'];
    if (token == null || userJson is! Map) {
      throw const ApiException(
        'A API retornou uma resposta de autenticação inválida.',
      );
    }
    _token = token;
    currentUser = UserProfile.fromJson(Map<String, dynamic>.from(userJson));
    activeShoppingListId = null;
    await _preferences.setString(_tokenKey, token);
    await _storeUser(currentUser!);
    return currentUser!;
  }

  Future<void> _storeUser(UserProfile user) async {
    await _preferences.setInt(_userIdKey, user.id);
    await _preferences.setString(_userNameKey, user.name);
    await _preferences.setString(_userEmailKey, user.email);
  }

  Future<void> logout() async {
    final userId = currentUser?.id ?? await _preferences.getInt(_userIdKey);
    _token = null;
    currentUser = null;
    activeShoppingListId = null;
    await _preferences.remove(_tokenKey);
    await _preferences.remove(_userIdKey);
    await _preferences.remove(_userNameKey);
    await _preferences.remove(_userEmailKey);
    if (userId != null) {
      await _preferences.remove('economarket_active_list_$userId');
    }
  }

  Future<UserProfile> updateProfile({
    required String name,
    required String email,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const ApiException('Entre novamente para editar o perfil.');
    }
    final json = await _requestMap(
      'PUT',
      '/usuarios/${user.id}',
      authenticated: true,
      body: {'nome': name, 'email': email},
    );
    currentUser = UserProfile.fromJson(json);
    await _storeUser(currentUser!);
    return currentUser!;
  }

  Future<Uint8List?> getProfilePhoto(UserProfile user) async {
    final encoded = await _preferences.getString(
      'economarket_profile_photo_${user.id}',
    );
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      await _preferences.remove('economarket_profile_photo_${user.id}');
      return null;
    }
  }

  Future<void> saveProfilePhoto(UserProfile user, Uint8List? photo) async {
    final key = 'economarket_profile_photo_${user.id}';
    if (photo == null) {
      await _preferences.remove(key);
      return;
    }
    await _preferences.setString(key, base64Encode(photo));
  }

  Future<List<Product>> getProducts() async {
    final data = await _requestList('GET', '/produtos');
    return data.map((json) => Product.fromJson(json)).toList();
  }

  Future<List<Market>> getMarkets() async {
    final data = await _requestList('GET', '/mercados');
    return data.map((json) => Market.fromJson(json)).toList();
  }

  Future<List<Category>> getCategories() async {
    final data = await _requestList('GET', '/categorias');
    return data.map((json) => Category.fromJson(json)).toList();
  }

  Future<List<ProductOffer>> getProductOffers() async {
    final data = await _requestList('GET', '/produtos-mercado');
    return data.map((json) => ProductOffer.fromJson(json)).toList();
  }

  Future<List<ShoppingList>> getShoppingLists() async {
    final data = await _requestList(
      'GET',
      '/listas-compras',
      authenticated: true,
    );
    return data.map((json) => ShoppingList.fromJson(json)).toList();
  }

  Future<ShoppingList> createShoppingList(String name) async {
    final json = await _requestMap(
      'POST',
      '/listas-compras',
      authenticated: true,
      body: {'nome': name},
    );
    final list = ShoppingList.fromJson(json);
    await selectShoppingList(list.id);
    shoppingListRevision.value++;
    return list;
  }

  Future<ShoppingList> ensureActiveShoppingList() async {
    final pending = _ensuringActiveList;
    if (pending != null) return pending;
    final future = _fetchOrCreateActiveList();
    _ensuringActiveList = future;
    try {
      return await future;
    } finally {
      _ensuringActiveList = null;
    }
  }

  Future<ShoppingList> _fetchOrCreateActiveList() async {
    final lists = await getShoppingLists();
    final selected = lists
        .where((entry) => entry.id == activeShoppingListId)
        .firstOrNull;
    final list = selected ?? lists.firstOrNull;
    if (list != null) {
      await selectShoppingList(list.id);
      return list;
    }
    return createShoppingList('Minha lista');
  }

  Future<void> selectShoppingList(int id) async {
    activeShoppingListId = id;
    final userId = currentUser?.id;
    if (userId != null) {
      await _preferences.setInt('economarket_active_list_$userId', id);
    }
  }

  Future<void> deleteShoppingList(int id) async {
    await _request('DELETE', '/listas-compras/$id', authenticated: true);
    if (activeShoppingListId == id) activeShoppingListId = null;
    shoppingListRevision.value++;
  }

  Future<ShoppingListItem> addProductToList({
    required int listId,
    required int productId,
    int quantity = 1,
  }) async {
    final lists = await getShoppingLists();
    final list = lists.where((entry) => entry.id == listId).firstOrNull;
    final existing = list?.items
        .where((entry) => entry.productId == productId)
        .firstOrNull;
    final Map<String, dynamic> json;
    if (existing == null) {
      json = await _requestMap(
        'POST',
        '/itens-lista',
        authenticated: true,
        body: {
          'listaDeComprasId': listId,
          'produtoId': productId,
          'quantidade': quantity,
        },
      );
    } else {
      json = await _requestMap(
        'PUT',
        '/itens-lista/${existing.id}',
        authenticated: true,
        body: {
          'listaDeComprasId': listId,
          'produtoId': productId,
          'quantidade': existing.quantity + quantity,
        },
      );
    }
    shoppingListRevision.value++;
    return ShoppingListItem.fromJson(json);
  }

  Future<ShoppingListItem> updateShoppingListItem(
    ShoppingListItem item, {
    required int listId,
    required int quantity,
  }) async {
    final json = await _requestMap(
      'PUT',
      '/itens-lista/${item.id}',
      authenticated: true,
      body: {
        'listaDeComprasId': listId,
        'produtoId': item.productId,
        'quantidade': quantity,
      },
    );
    shoppingListRevision.value++;
    return ShoppingListItem.fromJson(json);
  }

  Future<void> removeShoppingListItem(int id) async {
    await _request('DELETE', '/itens-lista/$id', authenticated: true);
    shoppingListRevision.value++;
  }

  Future<void> addProductToActiveList(int productId) async {
    final list = await ensureActiveShoppingList();
    await addProductToList(listId: list.id, productId: productId);
  }

  Future<List<Map<String, dynamic>>> _requestList(
    String method,
    String path, {
    bool authenticated = false,
  }) async {
    final value = await _request(method, path, authenticated: authenticated);
    if (value is! List) {
      throw const ApiException('A API retornou uma lista inválida.');
    }
    return value
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  Future<Map<String, dynamic>> _requestMap(
    String method,
    String path, {
    Object? body,
    bool authenticated = false,
  }) async {
    final value = await _request(
      method,
      path,
      body: body,
      authenticated: authenticated,
    );
    if (value is! Map) {
      throw const ApiException('A API retornou um objeto inválido.');
    }
    return Map<String, dynamic>.from(value);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    bool authenticated = false,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated) {
      final token = _token;
      if (token == null || token.isEmpty) {
        throw const ApiException('Sua sessão expirou. Entre novamente.');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    try {
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Falha ao comunicar com a API (${response.statusCode}).';
        try {
          final error = jsonDecode(response.body);
          if (error is Map && error['error'] is String) {
            message = error['error'] as String;
          }
        } catch (_) {}
        if (response.statusCode == 401 && authenticated) {
          await logout();
        }
        throw ApiException(message, statusCode: response.statusCode);
      }
      if (response.statusCode == 204 || response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Não foi possível conectar à API em $baseUrl: $error');
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class UserProfile {
  final int id;
  final String name;
  final String email;
  final String provider;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.provider,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: (json['id'] as num).toInt(),
    name: json['nome'] as String? ?? '',
    email: json['email'] as String? ?? '',
    provider: json['provedor'] as String? ?? 'LOCAL',
  );
}

class Category {
  final int id;
  final String name;

  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: (json['id'] as num).toInt(),
    name: json['nome'] as String? ?? '',
  );
}

class Market {
  final int id;
  final String name;
  final String? logoUrl;
  final bool active;

  const Market({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.active,
  });

  factory Market.fromJson(Map<String, dynamic> json) => Market(
    id: (json['id'] as num).toInt(),
    name: json['nome'] as String? ?? '',
    logoUrl: json['logoUrl'] as String?,
    active: json['ativo'] as bool? ?? true,
  );
}

class Product {
  final int id;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String category;
  final String unit;
  final List<ProductOffer> offers;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.category,
    required this.unit,
    required this.offers,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['categoria'];
    final offers = json['produtomercado'];
    return Product(
      id: (json['id'] as num).toInt(),
      name: json['nome'] as String? ?? '',
      brand: json['marca'] as String?,
      imageUrl: json['imagemUrl'] as String?,
      category: category is Map
          ? category['nome'] as String? ?? 'Outros'
          : 'Outros',
      unit: _unitLabel(json['quantidade'], json['unidade']),
      offers: offers is List
          ? offers
                .map(
                  (entry) => ProductOffer.fromJson(
                    Map<String, dynamic>.from(entry as Map),
                    productJson: json,
                  ),
                )
                .toList()
          : const [],
    );
  }

  List<ProductOffer> get availableOffers =>
      offers.where((offer) => offer.available).toList();

  ProductOffer? get bestOffer {
    final available = availableOffers;
    if (available.isEmpty) return null;
    available.sort((a, b) => a.price.compareTo(b.price));
    return available.first;
  }

  int? get discountPercent => bestOffer?.discountPercent;
}

class ProductOffer {
  final int id;
  final int productId;
  final int marketId;
  final String productName;
  final String? brand;
  final String category;
  final String unit;
  final String marketName;
  final String? marketLogoUrl;
  final double price;
  final double? originalPrice;
  final bool onPromotion;
  final bool available;
  final DateTime? promotionStart;
  final DateTime? promotionEnd;

  const ProductOffer({
    required this.id,
    required this.productId,
    required this.marketId,
    required this.productName,
    required this.brand,
    required this.category,
    required this.unit,
    required this.marketName,
    required this.marketLogoUrl,
    required this.price,
    required this.originalPrice,
    required this.onPromotion,
    required this.available,
    required this.promotionStart,
    required this.promotionEnd,
  });

  factory ProductOffer.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? productJson,
  }) {
    final product =
        (json['produto'] as Map?)?.cast<String, dynamic>() ??
        productJson ??
        const {};
    final market =
        (json['mercado'] as Map?)?.cast<String, dynamic>() ?? const {};
    final start = json['inicioPromocao'];
    final end = json['fimPromocao'];
    return ProductOffer(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId:
          (json['produtoId'] as num?)?.toInt() ??
          (product['id'] as num?)?.toInt() ??
          0,
      marketId:
          (json['mercadoId'] as num?)?.toInt() ??
          (market['id'] as num?)?.toInt() ??
          0,
      productName: product['nome'] as String? ?? '',
      brand: product['marca'] as String?,
      category: product['categoria'] is Map
          ? (product['categoria'] as Map)['nome'] as String? ?? 'Outros'
          : 'Outros',
      unit: _unitLabel(product['quantidade'], product['unidade']),
      marketName: market['nome'] as String? ?? '',
      marketLogoUrl: market['logoUrl'] as String?,
      price: _number(json['preco']),
      originalPrice: json['precoOriginal'] == null
          ? null
          : _number(json['precoOriginal']),
      onPromotion: json['emPromocao'] as bool? ?? false,
      available: json['disponivel'] as bool? ?? true,
      promotionStart: start is String ? DateTime.tryParse(start) : null,
      promotionEnd: end is String ? DateTime.tryParse(end) : null,
    );
  }

  int? get discountPercent {
    final oldPrice = originalPrice;
    if (!onPromotion ||
        oldPrice == null ||
        oldPrice <= price ||
        oldPrice == 0) {
      return null;
    }
    return ((oldPrice - price) / oldPrice * 100).round();
  }

  bool get isPromotionCurrent {
    final now = DateTime.now();
    return onPromotion &&
        available &&
        (promotionStart == null || !promotionStart!.isAfter(now)) &&
        (promotionEnd == null || !promotionEnd!.isBefore(now));
  }
}

class ShoppingList {
  final int id;
  final String name;
  final DateTime createdAt;
  final List<ShoppingListItem> items;

  const ShoppingList({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.items,
  });

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final items = json['itemlistacompra'];
    return ShoppingList(
      id: (json['id'] as num).toInt(),
      name: json['nome'] as String? ?? 'Minha lista',
      createdAt:
          DateTime.tryParse(json['criadoEm'] as String? ?? '') ??
          DateTime.now(),
      items: items is List
          ? items
                .map(
                  (entry) => ShoppingListItem.fromJson(
                    Map<String, dynamic>.from(entry as Map),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class ShoppingListItem {
  final int id;
  final int productId;
  final String productName;
  final String? brand;
  final String unit;
  final int quantity;

  const ShoppingListItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.brand,
    required this.unit,
    required this.quantity,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    final product =
        (json['produto'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ShoppingListItem(
      id: (json['id'] as num).toInt(),
      productId:
          (json['produtoId'] as num?)?.toInt() ??
          (product['id'] as num).toInt(),
      productName: product['nome'] as String? ?? 'Produto',
      brand: product['marca'] as String?,
      unit: _unitLabel(product['quantidade'], product['unidade']),
      quantity: (json['quantidade'] as num? ?? 1).toInt(),
    );
  }
}

String _unitLabel(dynamic quantity, dynamic unit) {
  final unitText = unit?.toString().trim() ?? '';
  if (quantity == null) return unitText.isEmpty ? 'Unidade' : unitText;
  final amount = _number(quantity);
  final amountText = amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toString().replaceAll('.', ',');
  if (unitText.isEmpty) return amountText;
  return '$amountText$unitText';
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
