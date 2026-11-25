import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/localizacao_mercados.dart';
import '../services/api_client.dart';
import '../services/localizacao_service.dart';
import '../style/colors.dart';
import '../style/home_style.dart';

class MercadosProximosPage extends StatefulWidget {
  final List<Market> mercados;

  const MercadosProximosPage({super.key, required this.mercados});

  @override
  State<MercadosProximosPage> createState() => _MercadosProximosPageState();
}

class _MercadosProximosPageState extends State<MercadosProximosPage> {
  bool _carregando = true;
  Position? _posicao;
  String? _mensagem;
  List<MercadoProximo> _proximos = [];

  @override
  void initState() {
    super.initState();
    _carregarLocalizacao();
  }

  Future<void> _carregarLocalizacao() async {
    setState(() {
      _carregando = true;
      _mensagem = null;
    });
    try {
      final posicao = await obterPosicao(
        aoNegarPermanentemente: _mostrarConfiguracaoPermissao,
      );
      if (!mounted) return;
      setState(() {
        _posicao = posicao;
        _proximos = posicao == null
            ? []
            : mercadosProximos(posicao, widget.mercados);
        _mensagem = posicao == null
            ? 'Não foi possível obter sua localização. Exibindo todos os mercados.'
            : null;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posicao = null;
        _proximos = [];
        _mensagem =
            'Não foi possível obter sua localização. Exibindo todos os mercados.';
        _carregando = false;
      });
    }
  }

  Future<void> _mostrarConfiguracaoPermissao() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'A permissão de localização está bloqueada nas configurações.',
          ),
          action: SnackBarAction(
            label: 'Configurações',
            onPressed: () => Geolocator.openAppSettings(),
          ),
        ),
      );
  }

  String _formatarDistancia(double distanciaKm) =>
      distanciaKm.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final semMercadosProximos =
        !_carregando && _posicao != null && _proximos.isEmpty;
    final mercadosExibidos = _posicao == null
        ? widget.mercados
        : semMercadosProximos
        ? widget.mercados
        : _proximos.map((item) => item.mercado).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mercados perto de você')),
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  _buildResumo(),
                  const SizedBox(height: 16),
                  if (_mensagem != null)
                    _buildAviso(_mensagem!, mostrarTentarNovamente: true)
                  else if (semMercadosProximos)
                    _buildAviso(
                      'Nenhum mercado cadastrado perto de você. Exibindo todos os mercados.',
                    ),
                  if (mercadosExibidos.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: HomeStyle.cardDecoration,
                      child: const Text(
                        'Nenhum mercado recebido da API.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ...mercadosExibidos.map(_buildMercadoCard),
                ],
              ),
      ),
    );
  }

  Widget _buildResumo() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: HomeStyle.cardDecoration,
    child: Row(
      children: [
        const Icon(Icons.storefront_outlined, color: AppColors.primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${widget.mercados.length} mercados recebidos',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (_posicao != null)
          const Text('Raio de 15 km', style: TextStyle(fontSize: 12)),
      ],
    ),
  );

  Widget _buildAviso(String mensagem, {bool mostrarTentarNovamente = false}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensagem),
            if (mostrarTentarNovamente) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _carregarLocalizacao,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      );

  Widget _buildMercadoCard(Market mercado) {
    final proximo = _proximos
        .where((item) => item.mercado.id == mercado.id)
        .firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: HomeStyle.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mercado.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (proximo != null)
            Text(
              'a ${_formatarDistancia(proximo.distanciaKm)} km',
              style: const TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
