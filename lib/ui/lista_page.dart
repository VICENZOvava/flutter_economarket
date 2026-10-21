import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../style/colors.dart';
import '../style/lista_style.dart';

class ListaPage extends StatefulWidget {
  const ListaPage({super.key});

  @override
  State<ListaPage> createState() => _ListaPageState();
}

class _ListaPageState extends State<ListaPage> {
  static const String _savedListsKey = 'economarket_saved_shopping_lists';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final List<_ListItem> _items = [
    _ListItem(name: 'Leite Integral', unit: '1L', quantity: 2),
    _ListItem(name: 'Arroz Branco', unit: '5kg', quantity: 1),
    _ListItem(name: 'Óleo de Soja', unit: '900ml', quantity: 1),
    _ListItem(name: 'Frango Inteiro', unit: 'kg', quantity: 1),
  ];
  List<_SavedList> _savedLists = [];
  bool _isLoadingSavedLists = true;

  int get _totalItems => _items.fold(0, (sum, item) => sum + item.quantity);

  @override
  void initState() {
    super.initState();
    _loadSavedLists();
  }

  Future<void> _loadSavedLists() async {
    try {
      final savedJson = await _preferences.getString(_savedListsKey);
      if (savedJson == null || savedJson.isEmpty) return;

      final decoded = jsonDecode(savedJson);
      if (decoded is! List) {
        throw const FormatException('Formato de listas inválido.');
      }

      final lists = decoded
          .map(
            (entry) => _SavedList.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();

      if (mounted) setState(() => _savedLists = lists);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar as listas salvas.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSavedLists = false);
    }
  }

  Future<void> _persistSavedLists(List<_SavedList> lists) async {
    final encoded = jsonEncode(lists.map((list) => list.toJson()).toList());
    await _preferences.setString(_savedListsKey, encoded);
  }

  void _increment(_ListItem item) {
    setState(() => item.quantity++);
  }

  void _decrement(_ListItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        _items.remove(item);
      }
    });
  }

  void _remove(_ListItem item) {
    setState(() => _items.remove(item));
  }

  void _clearList() {
    setState(() => _items.clear());
  }

  Future<void> _addItem() async {
    final item = await showDialog<_ListItem>(
      context: context,
      builder: (_) => const _AddItemDialog(),
    );

    if (item != null && mounted) {
      setState(() => _items.add(item));
    }
  }

  Future<void> _saveCurrentList() async {
    if (_items.isEmpty) return;

    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _ListNameDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    final savedList = _SavedList(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      items: _items.map((item) => item.copy()).toList(),
      savedAt: DateTime.now(),
    );
    final updatedLists = [savedList, ..._savedLists];

    try {
      await _persistSavedLists(updatedLists);
      if (!mounted) return;
      setState(() => _savedLists = updatedLists);
      _showMessage('Lista salva neste dispositivo.');
    } catch (_) {
      if (mounted) _showMessage('Não foi possível salvar a lista.');
    }
  }

  void _showSavedLists() {
    if (_isLoadingSavedLists) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _SavedListsSheet(
        lists: _savedLists,
        onUse: (savedList) {
          Navigator.of(sheetContext).pop();
          _useSavedList(savedList);
        },
        onDelete: (savedList) {
          Navigator.of(sheetContext).pop();
          _confirmDeleteSavedList(savedList);
        },
      ),
    );
  }

  Future<void> _useSavedList(_SavedList savedList) async {
    if (_items.isNotEmpty) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Substituir lista atual?'),
          content: Text(
            'A lista atual será substituída por “${savedList.name}”.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Usar lista'),
            ),
          ],
        ),
      );

      if (shouldReplace != true || !mounted) return;
    }

    setState(() {
      _items
        ..clear()
        ..addAll(savedList.items.map((item) => item.copy()));
    });
    _showMessage('Lista “${savedList.name}” carregada.');
  }

  Future<void> _confirmDeleteSavedList(_SavedList savedList) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir lista salva?'),
        content: Text('“${savedList.name}” será removida deste dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.promotionRed,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    final updatedLists =
        _savedLists.where((list) => list.id != savedList.id).toList();
    try {
      await _persistSavedLists(updatedLists);
      if (!mounted) return;
      setState(() => _savedLists = updatedLists);
      _showMessage('Lista removida.');
    } catch (_) {
      if (mounted) _showMessage('Não foi possível excluir a lista.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      itemBuilder: (context, index) => _ListItemCard(
                        item: _items[index],
                        onIncrement: () => _increment(_items[index]),
                        onDecrement: () => _decrement(_items[index]),
                        onRemove: () => _remove(_items[index]),
                      ),
                    ),
            ),
            if (_items.isNotEmpty) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Minha Lista', style: ListaStyle.titleStyle),
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
              onPressed: _isLoadingSavedLists ? null : _showSavedLists,
              icon: _isLoadingSavedLists
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmarks_outlined, size: 18),
              label: Text('Salvas (${_savedLists.length})'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        if (_items.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _clearList,
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
  }

  Widget _buildEmptyState() {
    return Center(
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
              'Adicione produtos para montar sua compra ou carregue uma lista salva.',
              textAlign: TextAlign.center,
              style: ListaStyle.emptySubtitleStyle,
            ),
            const SizedBox(height: 20),
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: ListaStyle.footerDecoration,
      child: Column(
        children: [
          _buildAddButton(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveCurrentList,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Salvar lista'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.bar_chart, size: 18),
                  label: const Text('Comparar preços'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: _addItem,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: ListaStyle.addButtonDecoration,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: AppColors.primaryGreen, size: 18),
            SizedBox(width: 6),
            Text('Adicionar produto', style: ListaStyle.addButtonTextStyle),
          ],
        ),
      ),
    );
  }
}

class _ListItem {
  final String name;
  final String unit;
  int quantity;

  _ListItem({
    required this.name,
    required this.unit,
    required this.quantity,
  });

  _ListItem copy() => _ListItem(
        name: name,
        unit: unit,
        quantity: quantity,
      );

  Map<String, Object> toJson() => {
        'name': name,
        'unit': unit,
        'quantity': quantity,
      };

  factory _ListItem.fromJson(Map<String, dynamic> json) => _ListItem(
        name: json['name'] as String,
        unit: json['unit'] as String,
        quantity: (json['quantity'] as num).toInt(),
      );
}

class _SavedList {
  final String id;
  final String name;
  final List<_ListItem> items;
  final DateTime savedAt;

  const _SavedList({
    required this.id,
    required this.name,
    required this.items,
    required this.savedAt,
  });

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((item) => item.toJson()).toList(),
        'savedAt': savedAt.toIso8601String(),
      };

  factory _SavedList.fromJson(Map<String, dynamic> json) {
    final entries = json['items'] as List;
    return _SavedList(
      id: json['id'] as String,
      name: json['name'] as String,
      items: entries
          .map(
            (entry) => _ListItem.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _unitController =
      TextEditingController(text: 'unidade');

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).pop(
      _ListItem(
        name: name,
        unit: _unitController.text.trim().isEmpty
            ? 'unidade'
            : _unitController.text.trim(),
        quantity: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar produto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome do produto',
              hintText: 'Ex.: Café',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unitController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Unidade ou tamanho',
              hintText: 'Ex.: 500g, 1L, pacote',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Adicionar'),
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
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Salvar lista'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Nome da lista',
          hintText: 'Ex.: Compra do mês',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _SavedListsSheet extends StatelessWidget {
  final List<_SavedList> lists;
  final ValueChanged<_SavedList> onUse;
  final ValueChanged<_SavedList> onDelete;

  const _SavedListsSheet({
    required this.lists,
    required this.onUse,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Listas salvas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Suas listas ficam salvas neste dispositivo.',
                style: ListaStyle.subtitleStyle,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: lists.isEmpty
                    ? const Center(
                        child: Text(
                          'Você ainda não salvou nenhuma lista.\n'
                          'Monte uma compra e toque em “Salvar lista”.',
                          textAlign: TextAlign.center,
                          style: ListaStyle.emptySubtitleStyle,
                        ),
                      )
                    : ListView.separated(
                        itemCount: lists.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final savedList = lists[index];
                          final total = savedList.items.fold(
                            0,
                            (sum, item) => sum + item.quantity,
                          );
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: ListaStyle.itemCardDecoration,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        savedList.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: ListaStyle.itemNameStyle,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Excluir lista',
                                      onPressed: () => onDelete(savedList),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${savedList.items.length} produtos · '
                                  '$total unidades · salva em '
                                  '${_formatDate(savedList.savedAt)}',
                                  style: ListaStyle.itemUnitStyle,
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => onUse(savedList),
                                    icon: const Icon(
                                      Icons.playlist_add_check,
                                      size: 18,
                                    ),
                                    label: const Text('Usar esta lista'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryGreen,
                                      side: const BorderSide(
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

class _ListItemCard extends StatelessWidget {
  final _ListItem item;
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
  Widget build(BuildContext context) {
    return Container(
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
                Text(item.name, style: ListaStyle.itemNameStyle),
                Text(item.unit, style: ListaStyle.itemUnitStyle),
              ],
            ),
          ),
          _buildQuantityStepper(),
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

  Widget _buildQuantityStepper() {
    return Container(
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
    );
  }
}
