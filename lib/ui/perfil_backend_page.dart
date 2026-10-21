import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../style/colors.dart';
import '../style/perfil_style.dart';
import 'login_screen.dart';

class PerfilBackendPage extends StatefulWidget {
  const PerfilBackendPage({super.key});

  @override
  State<PerfilBackendPage> createState() => _PerfilBackendPageState();
}

class _PerfilBackendPageState extends State<PerfilBackendPage> {
  final _api = ApiClient.instance;
  final _imagePicker = ImagePicker();
  UserProfile? _user;
  List<ShoppingList> _lists = [];
  List<Market> _markets = [];
  Uint8List? _profilePhoto;
  bool _loading = true;
  bool _refreshPending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api.shoppingListRevision.addListener(_onListsChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _api.shoppingListRevision.removeListener(_onListsChanged);
    super.dispose();
  }

  void _onListsChanged() {
    if (_loading) {
      _refreshPending = true;
    } else {
      _loadProfile();
    }
  }

  void _refreshIfPending() {
    if (!_refreshPending || !mounted) return;
    _refreshPending = false;
    Future<void>.delayed(Duration.zero, _loadProfile);
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.restoreSession(),
        _api.getShoppingLists(),
        _api.getMarkets(),
      ]);
      final user = results[0] as UserProfile?;
      final photo = user == null ? null : await _api.getProfilePhoto(user);
      if (!mounted) return;
      setState(() {
        _user = user;
        _profilePhoto = photo;
        _lists = results[1] as List<ShoppingList>;
        _markets = (results[2] as List<Market>)
            .where((market) => market.active)
            .toList();
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

  Future<void> _editProfile() async {
    final user = _user;
    if (user == null) return;
    final result = await showDialog<_ProfileInput>(
      context: context,
      builder: (_) =>
          _EditProfileDialog(user: user, profilePhoto: _profilePhoto),
    );
    if (result == null) return;
    try {
      final emailChanged =
          result.email.toLowerCase() != user.email.toLowerCase();
      final profileChanged =
          result.name != user.name || result.email != user.email;
      final updated = profileChanged
          ? await _api.updateProfile(name: result.name, email: result.email)
          : user;
      if (result.photoChanged) {
        await _api.saveProfilePhoto(updated, result.photoBytes);
      }
      if (emailChanged) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Perfil atualizado'),
            content: const Text(
              'Entre novamente com o novo e-mail para renovar sua sessão.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        await _logout();
        return;
      }
      if (mounted) {
        setState(() {
          _user = updated;
          if (result.photoChanged) _profilePhoto = result.photoBytes;
        });
      }
      if (mounted) _showMessage('Perfil atualizado.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _changePhoto() async {
    final user = _user;
    if (user == null) return;
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 640,
        maxHeight: 640,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await _api.saveProfilePhoto(user, bytes);
      if (mounted) setState(() => _profilePhoto = bytes);
    } catch (_) {
      if (mounted) _showMessage('Não foi possível salvar essa foto.');
    }
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadProfile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final totalItems = _lists.fold<int>(
      0,
      (sum, list) =>
          sum +
          list.items.fold(0, (subtotal, item) => subtotal + item.quantity),
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(totalItems),
                    const SizedBox(height: 16),
                    _buildMarketsCard(),
                    const SizedBox(height: 16),
                    _buildMenuList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = _user;
    return Container(
      width: double.infinity,
      padding: PerfilStyle.headerPadding,
      decoration: PerfilStyle.headerDecoration,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _profilePhoto == null
                    ? const Icon(Icons.person, color: Colors.white, size: 36)
                    : Image.memory(
                        _profilePhoto!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
              ),
              Positioned(
                right: -5,
                bottom: -4,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Editar foto de perfil',
                    onPressed: _changePhoto,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.photo_camera_outlined,
                      color: AppColors.primaryGreen,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.name ?? 'Usuário', style: PerfilStyle.nameStyle),
                const SizedBox(height: 2),
                Text(user?.email ?? '', style: PerfilStyle.emailStyle),
                const SizedBox(height: 8),
                Text(
                  user?.provider == 'GOOGLE'
                      ? 'Conta Google'
                      : 'Conta EconoMarket',
                  style: PerfilStyle.ratingLabelStyle,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar perfil',
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int totalItems) {
    final stats = [
      _StatItem(
        value: '${_lists.length}',
        label: 'Listas',
        color: AppColors.bestPriceGreen,
      ),
      _StatItem(
        value: '$totalItems',
        label: 'Itens nas listas',
        color: AppColors.bannerBlue,
      ),
      _StatItem(
        value: '${_markets.length}',
        label: 'Mercados',
        color: const Color(0xFFF9A825),
      ),
    ];
    return Row(
      children: stats
          .map(
            (stat) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 4,
                ),
                decoration: PerfilStyle.statCardDecoration,
                child: Column(
                  children: [
                    Text(
                      stat.value,
                      style: PerfilStyle.statValueStyle(stat.color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat.label,
                      textAlign: TextAlign.center,
                      style: PerfilStyle.statLabelStyle,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMarketsCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: PerfilStyle.sectionCardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mercados cadastrados',
          style: PerfilStyle.sectionTitleStyle,
        ),
        const SizedBox(height: 14),
        if (_markets.isEmpty)
          const Text(
            'Nenhum mercado ativo.',
            style: PerfilStyle.menuSubtitleStyle,
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _markets.map((market) {
              final initials = market.name
                  .split(RegExp(r'\s+'))
                  .where((part) => part.isNotEmpty)
                  .take(2)
                  .map((part) => part[0].toUpperCase())
                  .join();
              return Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: PerfilStyle.favoriteMarketBadgeDecoration(
                      const Color(0xFF2E7D32),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: PerfilStyle.favoriteMarketInitialsStyle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 80,
                    child: Text(
                      market.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: PerfilStyle.favoriteMarketLabelStyle,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
      ],
    ),
  );

  Widget _buildMenuList() => Container(
    width: double.infinity,
    decoration: PerfilStyle.sectionCardDecoration,
    child: Column(
      children: [
        _MenuRow(
          icon: Icons.receipt_long,
          background: const Color(0xFFFCE4EC),
          title: 'Minhas listas',
          subtitle: '${_lists.length} listas no servidor',
          onTap: () => _showLists(),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        _MenuRow(
          icon: Icons.person_outline,
          background: const Color(0xFFE3F2FD),
          title: 'Editar perfil',
          subtitle: 'Nome, e-mail e foto',
          onTap: _editProfile,
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        _MenuRow(
          icon: Icons.logout,
          background: const Color(0xFFFFEBEE),
          title: 'Sair da conta',
          subtitle: 'Encerrar esta sessão',
          onTap: _logout,
        ),
      ],
    ),
  );

  Future<void> _showLists() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Listas da sua conta',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ..._lists.map(
              (list) => ListTile(
                leading: const Icon(
                  Icons.list_alt,
                  color: AppColors.primaryGreen,
                ),
                title: Text(list.name),
                subtitle: Text('${list.items.length} produtos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(
      width: 40,
      height: 40,
      decoration: PerfilStyle.menuIconDecoration(background),
      child: Icon(icon, color: AppColors.textPrimary, size: 20),
    ),
    title: Text(title, style: PerfilStyle.menuTitleStyle),
    subtitle: Text(subtitle, style: PerfilStyle.menuSubtitleStyle),
    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
  );
}

class _ProfileInput {
  final String name;
  final String email;
  final Uint8List? photoBytes;
  final bool photoChanged;

  const _ProfileInput({
    required this.name,
    required this.email,
    required this.photoBytes,
    required this.photoChanged,
  });
}

class _EditProfileDialog extends StatefulWidget {
  final UserProfile user;
  final Uint8List? profilePhoto;

  const _EditProfileDialog({required this.user, required this.profilePhoto});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final _nameController = TextEditingController(text: widget.user.name);
  late final _emailController = TextEditingController(text: widget.user.email);
  late Uint8List? _photoBytes = widget.profilePhoto;
  bool _photoChanged = false;
  String? _photoError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ProfileInput(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        photoBytes: _photoBytes,
        photoChanged: _photoChanged,
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 640,
        maxHeight: 640,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoChanged = true;
        _photoError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _photoError = 'Não foi possível abrir essa imagem.');
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFF7F9F7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5EAE5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar perfil',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Mantenha seus dados atualizados.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primaryGreenLight,
                      backgroundImage: _photoBytes == null
                          ? null
                          : MemoryImage(_photoBytes!),
                      child: _photoBytes == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 46,
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(
                            _photoBytes == null
                                ? 'Adicionar foto'
                                : 'Trocar foto',
                          ),
                        ),
                        if (_photoBytes != null)
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _photoBytes = null;
                              _photoChanged = true;
                              _photoError = null;
                            }),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remover'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'A foto fica salva neste dispositivo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_photoError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _photoError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 20),
              const Text(
                'Dados da conta',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration(
                  label: 'Nome completo',
                  icon: Icons.person_outline,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe seu nome.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: _fieldDecoration(
                  label: 'E-mail',
                  icon: Icons.mail_outline,
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Informe um e-mail válido.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check),
                      label: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
