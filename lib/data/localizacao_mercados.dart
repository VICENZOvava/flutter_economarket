import '../services/api_client.dart';

class Coordenada {
  final double lat;
  final double lng;

  const Coordenada({required this.lat, required this.lng});
}

// Coordenadas fictícias apenas para validar a interface durante o desenvolvimento.
// TODO: trocar pelas coordenadas reais
const Map<int, Coordenada> coordenadasMercados = {
  1: Coordenada(lat: -23.5505, lng: -46.6333),
  2: Coordenada(lat: -23.5560, lng: -46.6400),
  3: Coordenada(lat: -23.5440, lng: -46.6250),
};

class MercadoProximo {
  final Market mercado;
  final double distanciaKm;

  const MercadoProximo({required this.mercado, required this.distanciaKm});
}
