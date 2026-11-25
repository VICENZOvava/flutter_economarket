import '../services/api_client.dart';

class Coordenada {
  final double lat;
  final double lng;

  const Coordenada({required this.lat, required this.lng});
}

// Coordenadas fornecidas para os mercados cadastrados em Amparo.
const Map<int, List<Coordenada>> coordenadasMercados = {
  // Spasso Sabores - Amparo (slug: spasso-sabores)
  8: [Coordenada(lat: -22.709677, lng: -46.779808)],
  // Poupe Bem (slug: poupe-bem), com duas localizações.
  9: [
    Coordenada(lat: -22.71456, lng: -46.81382),
    Coordenada(lat: -22.7191, lng: -46.7831),
  ],
  // Tenda Atacado - Amparo (slug: tenda-atacado); ponto aproximado informado.
  10: [Coordenada(lat: -22.70662, lng: -46.81559)],
  // Daolio (slug: daolio)
  11: [Coordenada(lat: -22.6995825, lng: -46.7590046)],
  // Antonelli (slug: antonelli)
  12: [Coordenada(lat: -22.71229, lng: -46.78019)],
  // Guarani (slug: guarani)
  13: [Coordenada(lat: -22.70435, lng: -46.76995)],
  // Santana (slug informado: Santana)
  14: [Coordenada(lat: -22.712866, lng: -46.780890)],
  // Unidos (slug: unidos)
  15: [Coordenada(lat: -22.69996, lng: -46.75666)],
};

class MercadoProximo {
  final Market mercado;
  final double distanciaKm;

  const MercadoProximo({required this.mercado, required this.distanciaKm});
}
