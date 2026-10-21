import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../style/colors.dart';
import '../style/lista_style.dart';

class ListaBackendPage extends StatefulWidget {
  const ListaBackendPage({super.key});

  @override
  State<ListaBackendPage> createState() => _ListaBackendPageState();
}

class _ListaBackendPageState extends State<ListaBackendPage> {
  final _api = ApiClient.instance;
  List<ShoppingList> _lists = [];
  ShoppingList? _activeList;
  bool _loading = true;
  bool _working = false;
  String? _error;

  List<ShoppingListItem> get _items => _activeList?.items ?? const [];
  int get _totalItems => _items.fold(0, (sum, item) => sum + item.quantity);

  @override
  void initState() {
    super.initState();
    _api.shoppingListRevision.addListener(_onListChangedElsewhere);
    _loadLists();
  }

  @override
  void dispose() {
    _api.shoppingListRevision.removeListener(_onListChangedElsewhere);
    super.dispose();
  }

  void _onListChangedElsewhere() {
    if (mounted && !_loading && !_working) _loadLists();
  }

  Future<void> _loadLists() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var lists = await _api.getShoppingLists();
      if (lists.isEmpty) {
        await _api.ensureActiveShoppingList();
        lists = await _api.getShoppingLists();
      }
      if (lists.isEmpty) {
        throw const ApiException('Não foi possível criar sua lista.');
      }
      final selected = lists
          .where((list) => list.id == _api.activeShoppingListId)
          .firstOrNull;
      final active = selected ?? lists.first;
      await _api.selectShoppingList(active.id);
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _activeList = active;
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

  Future<void> _refreshCurrentList() async {
    try {
      final lists = await _api.getShoppingLists();
      if (!mounted) return;
      final id = _activeList?.id ?? _api.activeShoppingListId;
      setState(() {
        _lists = lists;
        _activeList =
            lists.where((list) => list.id == id).firstOrNull ??
            lists.firstOrNull;
      });
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _addProduct() async {
    try {
      final products = await _api.getProducts();
      if (!mounted) return;
      final product = await showDialog<Product>(
        context: context,
        builder: (_) => _ProductPicker(products: products),
      );
      if (product == null || _activeList == null) return;
      setState(() => _working = true);
      await _api.addProductToList(
        listId: _activeList!.id,
        productId: product.id,
      );
      await _refreshCurrentList();
      if (mounted) _showMessage('${product.name} adicionado à lista.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _changeQuantity(ShoppingListItem item, int quantity) async {
    final list = _activeList;
    if (list == null || _working) return;
    setState(() => _working = true);
    try {
      if (quantity <= 0) {
        await _api.removeShoppingListItem(item.id);
      } else {
        await _api.updateShoppingListItem(
          item,
          listId: list.id,
          quantity: quantity,
        );
      }
      await _refreshCurrentList();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _clearList() async {
    if (_activeList == null || _items.isEmpty || _working) return;
    setState(() => _working = true);
    try {
      for (final item in _items) {
        await _api.removeShoppingListItem(item.id);
      }
      await _refreshCurrentList();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _createList() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _ListNameDialog(),
    );
    if (name == null || name.trim().isEmpty || _working) return;
    setState(() => _working = true);
    try {
      await _api.createShoppingList(name.trim());
      await _loadLists();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _saveCopy() async {
    if (_items.isEmpty) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _ListNameDialog(),
    );
    if (name == null || name.trim().isEmpty || _working || _activeList == null) {
      return;
    }
    setState(() => _working = true);
    try {
      final copy = await _api.createShoppingList(name.trim());
      for (final item in _items) {
        await _api.addProductToList(
          listId: copy.id,
          productId: item.productId,
          quantity: item.quantity,
        );
      }
      await _loadLists();
      if (mounted) _showMessage('Lista salva no servidor.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showLists() async {
    if (_loading || _working) return;
    final selectedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ShoppingListsSheet(
        lists: _lists,
        selectedId: _activeList?.id,
        onCreate: _createList,
        onDelete: _deleteList,
      ),
    );
    if (selectedId == null) return;
    final list = _lists.where((entry) => entry.id == selectedId).firstOrNull;
    if (list == null) return;
    await _api.selectShoppingList(list.id);
    _api.shoppingListRevision.value++;
    if (mounted) setState(() => _activeList = list);
  }

  Future<void> _deleteList(ShoppingList list) async {
    if (_working) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lista?'),
        content: Text(
          '“${list.name}” e seus itens serão removidos do servidor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.promotionRed,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      await _api.deleteShoppingList(list.id);
      await _loadLists();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loadLists,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _buildHeader(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _items.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _ListItemCard(
                          item: item,
                          onIncrement: () =>
                              _changeQuantity(item, item.quantity + 1),
                          onDecrement: () =>
                              _changeQuantity(item, item.quantity - 1),
                          onRemove: () => _changeQuantity(item, 0),
                        );
                      },
                    ),
            ),
            if (_items.isNotEmpty) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeList?.name ?? 'Minha lista',
                  style: ListaStyle.titleStyle,
                ),
                const SizedBox(height: 4),
                Text(
                  _items.isEmpty
                      ? 'Nenhum item adicionado'
                      : '$_totalItems ${_totalItems == 1 ? 'item' : 'itens'} na lista',
                  style: ListaStyle.subtitleStyle,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _working ? null : _showLists,
            icon: const Icon(Icons.bookmarks_outlined, size: 18),
            label: Text('Listas (${_lists.length})'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
      if (_items.isNotEmpty)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _working ? null : _clearList,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
            ),
            child: const Text(
              'Limpar lista',
              style: ListaStyle.clearActionStyle,
            ),
          ),
        ),
    ],
  );

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.list_alt_outlined,
            size: 56,
            color: AppColors.divider,
          ),
          const SizedBox(height: 16),
          const Text('Sua lista está vazia', style: ListaStyle.emptyTitleStyle),
          const SizedBox(height: 6),
          const Text(
            'Escolha produtos cadastrados para montar sua compra.',
            textAlign: TextAlign.center,
            style: ListaStyle.emptySubtitleStyle,
          ),
          const SizedBox(height: 20),
          _buildAddButton(),
        ],
      ),
    ),
  );

  Widget _buildFooter() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    decoration: ListaStyle.footerDecoration,
    child: Column(
      children: [
        _buildAddButton(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _working ? null : _saveCopy,
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Salvar como nova lista'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen),
              minimumSize: const Size(0, 48),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildAddButton() => InkWell(
    onTap: _working ? null : _addProduct,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: ListaStyle.addButtonDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 6),
          Text(
            _working ? 'Salvando...' : 'Adicionar produto',
            style: ListaStyle.addButtonTextStyle,
          ),
        ],
      ),
    ),
  );
}

class _ProductPicker extends StatefulWidget {
  final List<Product> products;

  const _ProductPicker({required this.products});

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final products = widget.products.where((product) {
      final query = _query.toLowerCase();
      return product.name.toLowerCase().contains(query) ||
          (product.brand?.toLowerCase().contains(query) ?? false);
    }).toList();
    return AlertDialog(
      title: const Text('Adicionar produto'),
      content: SizedBox(
        width: 360,
        height: 390,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar produto',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: products.isEmpty
                  ? const Center(child: Text('Nenhum produto encontrado.'))
                  : ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(product.name),
                          subtitle: Text(
                            '${product.category} · ${product.unit}',
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _ListNameDialog extends StatefulWidget {
  const _ListNameDialog();

  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nome da lista'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'Ex.: Compra do mês'),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Salvar')),
    ],
  );
}

class _ShoppingListsSheet extends StatelessWidget {
  final List<ShoppingList> lists;
  final int? selectedId;
  final Future<void> Function() onCreate;
  final Future<void> Function(ShoppingList) onDelete;

  const _ShoppingListsSheet({
    required this.lists,
    required this.selectedId,
    required this.onCreate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.of(context).size.height * .72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Suas listas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Criar lista',
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: lists.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final list = lists[index];
                  final count = list.items.fold(
                    0,
                    (sum, item) => sum + item.quantity,
                  );
                  return Container(
                    decoration: ListaStyle.itemCardDecoration,
                    child: ListTile(
                      leading: Icon(
                        list.id == selectedId
                            ? Icons.check_circle
                            : Icons.list_alt,
                        color: AppColors.primaryGreen,
                      ),
                      title: Text(list.name),
                      subtitle: Text(
                        '${list.items.length} produtos · $count unidades',
                      ),
                      onTap: () => Navigator.pop(context, list.id),
                      trailing: IconButton(
                        tooltip: 'Excluir lista',
                        onPressed: () => onDelete(list),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ListItemCard extends StatelessWidget {
  final ShoppingListItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _ListItemCard({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: ListaStyle.itemCardDecoration,
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: AppColors.textSecondary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.productName, style: ListaStyle.itemNameStyle),
              Text(item.unit, style: ListaStyle.itemUnitStyle),
            ],
          ),
        ),
        Container(
          decoration: ListaStyle.quantityStepperDecoration,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onDecrement,
                icon: const Icon(Icons.remove, size: 16),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                splashRadius: 16,
              ),
              SizedBox(
                width: 22,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: ListaStyle.quantityTextStyle,
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add, size: 16),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                splashRadius: 16,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(
            Icons.delete_outline,
            color: AppColors.textSecondary,
            size: 20,
          ),
          splashRadius: 20,
        ),
      ],
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
