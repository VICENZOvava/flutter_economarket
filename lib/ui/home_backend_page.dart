import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../style/colors.dart';
import '../style/home_style.dart';

class HomeBackendPage extends StatefulWidget {
  const HomeBackendPage({super.key});

  @override
  State<HomeBackendPage> createState() => _HomeBackendPageState();
}

class _HomeBackendPageState extends State<HomeBackendPage> {
  final _api = ApiClient.instance;
  List<Category> _categories = [];
  List<ProductOffer> _promotions = [];
  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getCategories(),
        _api.getProductOffers(),
        _api.getProducts(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<Category>;
        _promotions = (results[1] as List<ProductOffer>)
            .where((offer) => offer.isPromotionCurrent)
            .take(8)
            .toList();
        _products = results[2] as List<Product>;
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

  _MarketAverage? get _cheapestMarket {
    final totals = <String, List<double>>{};
    for (final product in _products) {
      for (final offer in product.availableOffers) {
        final values = totals.putIfAbsent(offer.marketName, () => [0, 0]);
        values[0] += offer.price;
        values[1]++;
      }
    }
    if (totals.isEmpty) return null;
    final averages =
        totals.entries
            .map(
              (entry) => _MarketAverage(
                entry.key,
                entry.value[0] / entry.value[1].toInt(),
              ),
            )
            .toList()
          ..sort((a, b) => a.average.compareTo(b.average));
    return averages.first;
  }

  Future<void> _addPromotion(ProductOffer offer) async {
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
    final userName = _api.currentUser?.name.split(' ').first ?? 'bem-vindo';
    final market = _cheapestMarket;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadHome,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(userName),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      _ErrorNotice(message: _error!, onRetry: _loadHome)
                    else if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (!_loading && _error == null) ...[
                      _buildOffersBanner(),
                      const SizedBox(height: 16),
                      if (market != null) _buildCheapestMarketCard(market),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Categorias',
                        '${_categories.length}',
                      ),
                      const SizedBox(height: 12),
                      _buildCategoriesList(),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Em promoção',
                        '${_promotions.length} ofertas',
                      ),
                      const SizedBox(height: 12),
                      _buildPromotionsList(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name) => Container(
    width: double.infinity,
    padding: HomeStyle.headerPadding,
    decoration: HomeStyle.headerDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Olá, $name 👋', style: HomeStyle.greetingStyle),
            const Icon(Icons.shopping_basket_outlined, color: Colors.white),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Onde vai economizar\nhoje?', style: HomeStyle.titleStyle),
        const SizedBox(height: 16),
        TextField(
          readOnly: true,
          onTap: () => _showMessage('Use a aba Produtos para pesquisar.'),
          decoration: InputDecoration(
            hintText: 'Pesquisar produto...',
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildOffersBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: HomeStyle.bannerDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.local_offer_outlined, color: Colors.white),
        ),
        const SizedBox(height: 12),
        const Text('Ofertas do servidor', style: HomeStyle.bannerTitleStyle),
        const SizedBox(height: 4),
        Text(
          _promotions.isEmpty
              ? 'Ainda não há promoções ativas cadastradas.'
              : '${_promotions.length} ofertas ativas para você conferir.',
          style: HomeStyle.bannerSubtitleStyle,
        ),
      ],
    ),
  );

  Widget _buildCheapestMarketCard(_MarketAverage market) => Container(
    padding: const EdgeInsets.all(16),
    decoration: HomeStyle.cardDecoration,
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.bestPriceBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.storefront, color: AppColors.bestPriceGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Menor preço médio cadastrado',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                market.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bestPriceGreen,
                ),
              ),
              Text(
                _formatPrice(market.average),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.bestPriceGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildSectionHeader(String title, String actionLabel) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      Text(
        actionLabel,
        style: const TextStyle(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ],
  );

  Widget _buildCategoriesList() {
    if (_categories.isEmpty) return const Text('Nenhuma categoria cadastrada.');
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final colors = const [
            Color(0xFFDCEFE1),
            Color(0xFFFBDDDD),
            Color(0xFFDDEAFB),
            Color(0xFFEDE0F7),
            Color(0xFFFCE0EE),
          ];
          return Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: HomeStyle.categoryIconDecoration(
                  colors[index % colors.length],
                ),
                child: Icon(
                  _categoryIcon(category.name),
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 70,
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: HomeStyle.categoryLabelStyle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _categoryIcon(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('bebida')) return Icons.local_drink;
    if (normalized.contains('limp')) return Icons.cleaning_services;
    if (normalized.contains('hig')) return Icons.soap;
    if (normalized.contains('frios') || normalized.contains('latic')) {
      return Icons.egg_alt;
    }
    if (normalized.contains('hort')) return Icons.eco;
    return Icons.shopping_basket_outlined;
  }

  Widget _buildPromotionsList() {
    if (_promotions.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'As ofertas aparecem aqui quando cadastradas no backend.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return SizedBox(
      height: 205,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _promotions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _PromoCard(
          offer: _promotions[index],
          onAdd: () => _addPromotion(_promotions[index]),
        ),
      ),
    );
  }

  String _formatPrice(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _MarketAverage {
  final String name;
  final double average;

  const _MarketAverage(this.name, this.average);
}

class _PromoCard extends StatelessWidget {
  final ProductOffer offer;
  final VoidCallback onAdd;

  const _PromoCard({required this.offer, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final discount = offer.discountPercent;
    return Container(
      width: 150,
      decoration: HomeStyle.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 90,
                width: double.infinity,
                color: AppColors.divider,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.textSecondary,
                  size: 32,
                ),
              ),
              if (discount != null)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: HomeStyle.discountBadgeDecoration,
                    child: Text(
                      '-$discount%',
                      style: HomeStyle.discountBadgeTextStyle,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        offer.marketName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (offer.originalPrice != null && discount != null)
                        Text(
                          _formatPrice(offer.originalPrice!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.priceStrikethrough,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        _formatPrice(offer.price),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.promotionRed,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: onAdd,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _ErrorNotice extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorNotice({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}
