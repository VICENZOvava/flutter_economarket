import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../style/colors.dart';
import '../style/promocoes_style.dart';

class PromocoesBackendPage extends StatefulWidget {
  const PromocoesBackendPage({super.key});

  @override
  State<PromocoesBackendPage> createState() => _PromocoesBackendPageState();
}

class _PromocoesBackendPageState extends State<PromocoesBackendPage> {
  final _api = ApiClient.instance;
  List<ProductOffer> _offers = [];
  Map<int, String> _categoriesByProduct = {};
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'Todos';

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getProductOffers(),
        _api.getProducts(),
      ]);
      final offers = results[0] as List<ProductOffer>;
      final products = results[1] as List<Product>;
      if (!mounted) return;
      setState(() {
        _offers = offers.where((offer) => offer.isPromotionCurrent).toList();
        _categoriesByProduct = {
          for (final product in products) product.id: product.category,
        };
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String _category(ProductOffer offer) =>
      _categoriesByProduct[offer.productId] ?? offer.category;

  List<String> get _categories => [
    'Todos',
    ..._offers.map(_category).toSet().toList()..sort(),
  ];

  List<ProductOffer> get _filtered => _selectedCategory == 'Todos'
      ? _offers
      : _offers
            .where((offer) => _category(offer) == _selectedCategory)
            .toList();

  Future<void> _add(ProductOffer offer) async {
    try {
      await _api.addProductToActiveList(offer.productId);
      if (mounted) _showMessage('${offer.productName} adicionado à lista.');
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
    final offers = _filtered;
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
                  const Text('Promoções', style: PromocoesStyle.titleStyle),
                  const SizedBox(height: 4),
                  Text(
                    '${_offers.length} ofertas disponíveis',
                    style: PromocoesStyle.subtitleStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_loading && _error == null && _categories.length > 1)
              SizedBox(
                height: 40,
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
                        decoration: PromocoesStyle.filterChipDecoration(active),
                        child: Text(
                          category,
                          style: PromocoesStyle.filterChipTextStyle(active),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Expanded(child: _buildContent(offers)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<ProductOffer> offers) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _MessageState(
        message: _error!,
        action: 'Tentar novamente',
        onPressed: _loadOffers,
      );
    }
    if (offers.isEmpty) {
      return const _MessageState(
        message: 'Nenhuma promoção ativa foi cadastrada no servidor.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: offers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _PromotionCard(
        offer: offers[index],
        onAdd: () => _add(offers[index]),
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  final ProductOffer offer;
  final VoidCallback onAdd;

  const _PromotionCard({required this.offer, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final discount = offer.discountPercent;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: PromocoesStyle.cardDecoration,
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.textSecondary,
                  size: 28,
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
                    decoration: PromocoesStyle.discountBadgeDecoration,
                    child: Text(
                      '-$discount%',
                      style: PromocoesStyle.discountBadgeTextStyle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offer.brand?.isNotEmpty == true)
                  Text(offer.brand!, style: PromocoesStyle.brandStyle),
                Text(
                  offer.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PromocoesStyle.nameStyle,
                ),
                Text(offer.marketName, style: PromocoesStyle.marketStyle),
                const SizedBox(height: 4),
                if (offer.originalPrice != null && discount != null)
                  Text(
                    _formatPrice(offer.originalPrice!),
                    style: PromocoesStyle.oldPriceStyle,
                  ),
                Text(
                  _formatPrice(offer.price),
                  style: PromocoesStyle.newPriceStyle,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Adicionar à lista',
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle, color: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _MessageState extends StatelessWidget {
  final String message;
  final String? action;
  final VoidCallback? onPressed;

  const _MessageState({required this.message, this.action, this.onPressed});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onPressed, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}
