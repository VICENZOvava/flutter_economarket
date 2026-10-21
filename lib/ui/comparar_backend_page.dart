import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../style/colors.dart';
import '../style/comparar_style.dart';

class CompararBackendPage extends StatefulWidget {
  const CompararBackendPage({super.key});

  @override
  State<CompararBackendPage> createState() => _CompararBackendPageState();
}

class _CompararBackendPageState extends State<CompararBackendPage> {
  final _api = ApiClient.instance;
  List<Market> _markets = [];
  List<Product> _products = [];
  ShoppingList? _list;
  bool _loading = true;
  bool _refreshPending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api.shoppingListRevision.addListener(_onListChanged);
    _loadComparison();
  }

  @override
  void dispose() {
    _api.shoppingListRevision.removeListener(_onListChanged);
    super.dispose();
  }

  void _onListChanged() {
    if (_loading) {
      _refreshPending = true;
    } else {
      _loadComparison();
    }
  }

  void _refreshIfPending() {
    if (!_refreshPending || !mounted) return;
    _refreshPending = false;
    Future<void>.delayed(Duration.zero, _loadComparison);
  }

  Future<void> _loadComparison() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getMarkets(),
        _api.getProducts(),
        _api.getShoppingLists(),
      ]);
      final markets = (results[0] as List<Market>)
          .where((market) => market.active)
          .toList();
      final products = results[1] as List<Product>;
      final lists = results[2] as List<ShoppingList>;
      final selected = lists
          .where((list) => list.id == _api.activeShoppingListId)
          .firstOrNull;
      final list = selected ?? lists.firstOrNull;
      if (list != null) await _api.selectShoppingList(list.id);
      if (!mounted) return;
      setState(() {
        _markets = markets;
        _products = products;
        _list = list;
        _loading = false;
      });
      _refreshIfPending();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
      _refreshIfPending();
    }
  }

  Map<int, Product> get _productsById => {
    for (final product in _products) product.id: product,
  };

  List<_MarketTotal> get _marketTotals {
    final list = _list;
    if (list == null || list.items.isEmpty) return const [];
    final productsById = _productsById;
    return _markets.map((market) {
      var total = 0.0;
      var coveredItems = 0;
      for (final item in list.items) {
        final product = productsById[item.productId];
        final offer = product?.offers
            .where((entry) => entry.marketId == market.id && entry.available)
            .firstOrNull;
        if (offer == null) continue;
        coveredItems++;
        total += offer.price * item.quantity;
      }
      return _MarketTotal(
        name: market.name,
        total: total,
        coveredItems: coveredItems,
        complete: coveredItems == list.items.length,
      );
    }).toList()..sort((a, b) {
      if (a.complete != b.complete) return a.complete ? -1 : 1;
      return a.total.compareTo(b.total);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadComparison,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final totals = _marketTotals;
    final complete = totals.where((total) => total.complete).toList();
    final best = complete.firstOrNull;
    final worst = complete.isEmpty ? null : complete.last;
    final economy = best == null || worst == null
        ? 0.0
        : worst.total - best.total;
    final list = _list;

    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadComparison,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text('Comparar preços', style: CompararStyle.titleStyle),
              const SizedBox(height: 4),
              Text(
                list == null
                    ? 'Nenhuma lista cadastrada'
                    : '${list.name} · ${list.items.length} produtos · ${_markets.length} mercados',
                style: CompararStyle.subtitleStyle,
              ),
              const SizedBox(height: 16),
              if (list == null || list.items.isEmpty)
                _emptyListState()
              else ...[
                if (best != null) _buildBestMarketCard(best, economy),
                if (best == null)
                  _notice(
                    'Ainda não há preço para todos os itens em um mesmo mercado. '
                    'Os totais parciais aparecem abaixo.',
                  ),
                const SizedBox(height: 16),
                _buildMarketTotals(totals, list.items.length),
                const SizedBox(height: 16),
                _buildProductsCard(list),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyListState() => Container(
    margin: const EdgeInsets.only(top: 70),
    padding: const EdgeInsets.all(24),
    decoration: CompararStyle.sectionCardDecoration,
    child: const Column(
      children: [
        Icon(
          Icons.shopping_cart_outlined,
          size: 44,
          color: AppColors.textSecondary,
        ),
        SizedBox(height: 12),
        Text(
          'Adicione produtos à sua lista para comparar os mercados.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _notice(String message) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
  );

  Widget _buildBestMarketCard(_MarketTotal best, double economy) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: CompararStyle.bestMarketCardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('🏆', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Mais econômico para sua lista',
                style: CompararStyle.bestMarketLabelStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(best.name, style: CompararStyle.bestMarketNameStyle),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _stat(
                'Total da compra',
                _formatPrice(best.total),
                Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _stat(
                'Economia possível',
                _formatPrice(economy),
                AppColors.highlightYellow,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _stat(String label, String value, Color valueColor) => Container(
    padding: const EdgeInsets.all(12),
    decoration: CompararStyle.totalCardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CompararStyle.innerStatLabelStyle),
        const SizedBox(height: 4),
        Text(value, style: CompararStyle.innerStatValueStyle(valueColor)),
      ],
    ),
  );

  Widget _buildMarketTotals(
    List<_MarketTotal> totals,
    int productCount,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: CompararStyle.sectionCardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Total por mercado', style: CompararStyle.sectionTitleStyle),
        const SizedBox(height: 16),
        if (totals.isEmpty)
          const Text('Nenhum mercado ativo disponível.')
        else
          ...totals.map((market) {
            final isBest =
                market.complete &&
                totals.where((entry) => entry.complete).firstOrNull == market;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          market.name,
                          style: CompararStyle.barLabelStyle,
                        ),
                      ),
                      Text(
                        market.complete
                            ? _formatPrice(market.total)
                            : '${_formatPrice(market.total)} · ${market.coveredItems}/$productCount itens',
                        style: CompararStyle.barValueStyle(isBest),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final maxTotal = totals
                          .map((entry) => entry.total)
                          .reduce((a, b) => a > b ? a : b);
                      final width = maxTotal == 0
                          ? 0.0
                          : constraints.maxWidth * market.total / maxTotal;
                      return Container(
                        height: 6,
                        width: width,
                        decoration: BoxDecoration(
                          color: isBest
                              ? CompararStyle.barBestColor
                              : CompararStyle.barDefaultColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    ),
  );

  Widget _buildProductsCard(ShoppingList list) => Container(
    width: double.infinity,
    decoration: CompararStyle.sectionCardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Preços por produto',
            style: CompararStyle.sectionTitleStyle,
          ),
        ),
        ...list.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final product = _productsById[item.productId];
          return Column(
            children: [
              _ProductComparisonRow(
                item: item,
                offers: product?.availableOffers ?? const [],
              ),
              if (index < list.items.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _MarketTotal {
  final String name;
  final double total;
  final int coveredItems;
  final bool complete;

  const _MarketTotal({
    required this.name,
    required this.total,
    required this.coveredItems,
    required this.complete,
  });
}

class _ProductComparisonRow extends StatelessWidget {
  final ShoppingListItem item;
  final List<ProductOffer> offers;

  const _ProductComparisonRow({required this.item, required this.offers});

  @override
  Widget build(BuildContext context) {
    final sorted = [...offers]..sort((a, b) => a.price.compareTo(b.price));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: CompararStyle.productNameStyle,
                    ),
                    Text(
                      '${item.unit} · ${item.quantity}x',
                      style: CompararStyle.productSubtitleStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            const Text(
              'Sem preços cadastrados para este produto.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) =>
                    _PriceChip(offer: sorted[index], isBest: index == 0),
              ),
            ),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final ProductOffer offer;
  final bool isBest;

  const _PriceChip({required this.offer, required this.isBest});

  @override
  Widget build(BuildContext context) => Container(
    width: 110,
    padding: const EdgeInsets.all(8),
    decoration: CompararStyle.priceCardDecoration(isBest),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              offer.marketName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CompararStyle.priceCardMarketStyle,
            ),
            const SizedBox(height: 4),
            if (offer.originalPrice != null && offer.discountPercent != null)
              Text(
                _formatPrice(offer.originalPrice!),
                style: CompararStyle.priceCardOldPriceStyle,
              ),
            Text(
              _formatPrice(offer.price),
              style: CompararStyle.priceCardNewPriceStyle(isBest),
            ),
            if (isBest) ...[
              const SizedBox(height: 2),
              const Text(
                'Melhor preço',
                style: CompararStyle.bestPriceTagStyle,
              ),
            ],
          ],
        ),
        if (offer.discountPercent != null)
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: CompararStyle.discountBadgeDecoration,
              child: Text(
                '-${offer.discountPercent}%',
                style: CompararStyle.discountBadgeTextStyle,
              ),
            ),
          ),
      ],
    ),
  );
}

String _formatPrice(double value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
