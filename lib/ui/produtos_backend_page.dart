import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../style/colors.dart';
import '../style/produtos_style.dart';

class ProdutosBackendPage extends StatefulWidget {
  const ProdutosBackendPage({super.key});

  @override
  State<ProdutosBackendPage> createState() => _ProdutosBackendPageState();
}

class _ProdutosBackendPageState extends State<ProdutosBackendPage> {
  final _api = ApiClient.instance;
  final _searchController = TextEditingController();
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'Todos';
  bool _sortByDiscount = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _api.getProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
        if (_selectedCategory != 'Todos' &&
            !products.any((product) => product.category == _selectedCategory)) {
          _selectedCategory = 'Todos';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<String> get _categories => [
    'Todos',
    ..._products.map((product) => product.category).toSet().toList()..sort(),
  ];

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    final products = _products.where((product) {
      final matchesCategory =
          _selectedCategory == 'Todos' || product.category == _selectedCategory;
      final matchesSearch =
          product.name.toLowerCase().contains(query) ||
          (product.brand?.toLowerCase().contains(query) ?? false);
      return matchesCategory && matchesSearch;
    }).toList();
    products.sort((a, b) {
      if (_sortByDiscount) {
        return (b.discountPercent ?? 0).compareTo(a.discountPercent ?? 0);
      }
      return (a.bestOffer?.price ?? double.infinity).compareTo(
        b.bestOffer?.price ?? double.infinity,
      );
    });
    return products;
  }

  Future<void> _addProduct(Product product) async {
    try {
      await _api.addProductToActiveList(product.id);
      if (mounted) _showMessage('${product.name} adicionado à lista.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Produtos', style: ProdutosStyle.titleStyle),
                  const SizedBox(height: 4),
                  Text(
                    '${products.length} ${products.length == 1 ? 'produto encontrado' : 'produtos encontrados'}',
                    style: ProdutosStyle.subtitleStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: ProdutosStyle.searchFieldDecoration(),
              ),
            ),
            const SizedBox(height: 14),
            if (!_loading && _error == null && _categories.length > 1)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final active = category == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: ProdutosStyle.categoryChipDecoration(
                          active,
                        ),
                        child: Text(
                          category,
                          style: ProdutosStyle.categoryChipTextStyle(active),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Ordenar:', style: ProdutosStyle.sortLabelStyle),
                  const SizedBox(width: 8),
                  _sortChip('Menor preço', false),
                  const SizedBox(width: 8),
                  _sortChip('Maior desconto', true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults(products)),
          ],
        ),
      ),
    );
  }

  Widget _sortChip(String label, bool discount) {
    final active = _sortByDiscount == discount;
    return GestureDetector(
      onTap: () => setState(() => _sortByDiscount = discount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: ProdutosStyle.sortChipDecoration(active),
        child: Text(label, style: ProdutosStyle.sortChipTextStyle(active)),
      ),
    );
  }

  Widget _buildResults(List<Product> products) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadProducts);
    }
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum produto encontrado',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) => _ProductCard(
        product: products[index],
        onAdd: () => _addProduct(products[index]),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;

  const _ProductCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final offer = product.bestOffer;
    final discount = offer?.discountPercent;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: ProdutosStyle.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.imageUrl == null || product.imageUrl!.isEmpty
                      ? _placeholder()
                      : Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(),
                        ),
                ),
              ),
              if (discount != null)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: ProdutosStyle.discountBadgeDecoration,
                    child: Text(
                      '-$discount%',
                      style: ProdutosStyle.discountBadgeTextStyle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ProdutosStyle.productNameStyle,
          ),
          const SizedBox(height: 2),
          Text(product.category, style: ProdutosStyle.productCategoryStyle),
          const Spacer(),
          if (offer == null) ...[
            const Text(
              'Preço indisponível',
              style: ProdutosStyle.bestPriceLabelStyle,
            ),
          ] else ...[
            Text(
              offer.marketName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ProdutosStyle.bestPriceMarketStyle,
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (offer.originalPrice != null && discount != null)
                        Text(
                          _formatPrice(offer.originalPrice!),
                          style: ProdutosStyle.oldPriceStyle,
                        ),
                      Text(
                        _formatPrice(offer.price),
                        style: ProdutosStyle.bestPriceValueStyle,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: ProdutosStyle.addButtonDecoration,
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.divider,
    alignment: Alignment.center,
    child: const Icon(
      Icons.shopping_bag_outlined,
      color: AppColors.textSecondary,
      size: 28,
    ),
  );

  String _formatPrice(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 42, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
