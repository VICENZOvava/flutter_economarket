import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../style/colors.dart';
import '../style/home_style.dart';
import 'produtos_backend_page.dart';

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

  List<_MarketAverage> get _marketRankings {
    final totals = <String, List<double>>{};
    for (final product in _products) {
      for (final offer in product.availableOffers) {
        final values = totals.putIfAbsent(offer.marketName, () => [0, 0]);
        values[0] += offer.price;
        values[1]++;
      }
    }
    final rankings = totals.entries
        .map(
          (entry) => _MarketAverage(
            entry.key,
            entry.value[0] / entry.value[1],
            offerCount: entry.value[1].toInt(),
          ),
        )
        .toList()
      ..sort((a, b) => a.average.compareTo(b.average));
    return rankings;
  }

  List<_ProductDeal> get _featuredProductDeals {
    final deals = <_ProductDeal>[];
    for (final product in _products) {
      final offer = product.bestOffer;
      if (offer != null) deals.add(_ProductDeal(product, offer));
    }
    deals.sort((a, b) => a.offer.price.compareTo(b.offer.price));
    return deals;
  }

  Future<void> _addPromotion(ProductOffer offer) async {
    try {
      await _api.addProductToActiveList(offer.productId);
      if (mounted) _showMessage('${offer.productName} adicionado à lista.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<List<ProductOffer>> _loadNotifications() async {
    final offers = await _api.getProductOffers();
    final activeOffers = offers
        .where((offer) => offer.isPromotionCurrent)
        .toList();
    if (mounted) setState(() => _promotions = activeOffers);
    return activeOffers;
  }

  void _openNotifications() {
    final offersFuture = _loadNotifications();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NotificationsSheet(
        offersFuture: offersFuture,
        initialOffers: _promotions,
        onAdd: _addPromotion,
      ),
    );
  }

  void _openCategory(String category) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProdutosBackendPage(initialCategory: category),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final userName = _api.currentUser?.name.split(' ').first ?? 'bem-vindo';
    final marketRankings = _marketRankings;
    final productDeals = _featuredProductDeals;
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
                      _FeaturedProductCarousel(deals: productDeals),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Categorias',
                        '${_categories.length}',
                      ),
                      const SizedBox(height: 12),
                      _buildCategoriesList(),
                      const SizedBox(height: 24),
                      _buildMarketComparisonHeader(),
                      const SizedBox(height: 8),
                      _buildMarketRankingList(marketRankings),
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
            _buildNotificationButton(),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Onde vai economizar\nhoje?', style: HomeStyle.titleStyle),
        const SizedBox(height: 16),
        TextField(
          readOnly: true,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ProdutosBackendPage(),
            ),
          ),
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

  Widget _buildNotificationButton() => IconButton(
    tooltip: 'Notificações',
    onPressed: _openNotifications,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    icon: SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.notifications_none, color: Colors.white),
            ),
          ),
          if (_promotions.isNotEmpty)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.promotionRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  _promotions.length > 99 ? '99+' : '${_promotions.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
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

  Widget _buildMarketComparisonHeader() => Row(
    children: [
      const Text(
        'Onde está mais barato?',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      IconButton(
        tooltip: 'Sobre a comparação',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: const Text(
              'Comparação feita com base em todos os produtos disponíveis de cada mercado.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendi'),
              ),
            ],
          ),
        ),
        icon: const Icon(Icons.info_outline, size: 20),
        color: AppColors.textSecondary,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.only(left: 4),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
          return InkWell(
            onTap: () => _openCategory(category.name),
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 70,
              child: Column(
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
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: HomeStyle.categoryLabelStyle,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMarketRankingList(List<_MarketAverage> rankings) {
    final topMarkets = rankings.take(3).toList();
    if (topMarkets.isEmpty) {
      return const Text(
        'Ainda não há preços suficientes para comparar mercados.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < topMarkets.length; index++) ...[
          if (index > 0) const Divider(height: 1, indent: 44),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? AppColors.bestPriceBackground
                        : const Color(0xFFF0F2F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: index == 0
                          ? AppColors.bestPriceGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topMarkets[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Média de ${topMarkets[index].offerCount} preços',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatPrice(topMarkets[index].average),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ],
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

  String _formatPrice(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _NotificationsSheet extends StatelessWidget {
  final Future<List<ProductOffer>> offersFuture;
  final List<ProductOffer> initialOffers;
  final ValueChanged<ProductOffer> onAdd;

  const _NotificationsSheet({
    required this.offersFuture,
    required this.initialOffers,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.72,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notificações',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Promoções ativas nos mercados',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<ProductOffer>>(
            future: offersFuture,
            initialData: initialOffers,
            builder: (context, snapshot) {
              if (snapshot.hasError && (snapshot.data?.isEmpty ?? true)) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Não foi possível carregar as notificações. Tente novamente mais tarde.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              final offers = snapshot.data ?? initialOffers;
              if (offers.isEmpty &&
                  snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (offers.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 36,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Nenhuma promoção nova por enquanto.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: offers.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _PromotionNotificationTile(
                  offer: offers[index],
                  onAdd: () => onAdd(offers[index]),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _PromotionNotificationTile extends StatelessWidget {
  final ProductOffer offer;
  final VoidCallback onAdd;

  const _PromotionNotificationTile({required this.offer, required this.onAdd});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFE4F2E9),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.local_offer_outlined, color: AppColors.primaryGreen),
    ),
    title: Text(
      offer.productName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      '${offer.marketName} - ${_formatPrice(offer.price)}'
      '${offer.discountPercent == null ? '' : ' (${offer.discountPercent}% off)'}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: IconButton(
      tooltip: 'Adicionar à lista',
      onPressed: onAdd,
      icon: const Icon(Icons.add_shopping_cart, color: AppColors.primaryGreen),
    ),
  );

  String _formatPrice(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _MarketAverage {
  final String name;
  final double average;
  final int offerCount;

  const _MarketAverage(this.name, this.average, {required this.offerCount});
}

class _ProductDeal {
  final Product product;
  final ProductOffer offer;

  const _ProductDeal(this.product, this.offer);
}

class _FeaturedProductCarousel extends StatefulWidget {
  final List<_ProductDeal> deals;

  const _FeaturedProductCarousel({required this.deals});

  @override
  State<_FeaturedProductCarousel> createState() =>
      _FeaturedProductCarouselState();
}

class _FeaturedProductCarouselState extends State<_FeaturedProductCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.94);
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _FeaturedProductCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deals.length != widget.deals.length) {
      _currentPage = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _timer?.cancel();
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    if (widget.deals.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      final nextPage = (_currentPage + 1) % widget.deals.length;
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deals.isEmpty) {
      return const Text(
        'Ainda não há produtos com preços disponíveis.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Produtos mais baratos',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.deals.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _FeaturedProductCard(deal: widget.deals[index]),
            ),
          ),
        ),
        if (widget.deals.length > 1) ...[
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_currentPage + 1} / ${widget.deals.length}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeaturedProductCard extends StatelessWidget {
  final _ProductDeal deal;

  const _FeaturedProductCard({required this.deal});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: HomeStyle.cardDecoration,
    child: Row(
      children: [
        _ProductImage(imageUrl: deal.product.imageUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                deal.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (deal.product.brand?.isNotEmpty == true)
                Text(
                  deal.product.brand!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      deal.offer.marketName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    'R\$ ${deal.offer.price.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.bestPriceGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;

  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final fallback = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.bestPriceBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.shopping_basket_outlined,
        color: AppColors.bestPriceGreen,
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
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
