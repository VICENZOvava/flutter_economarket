import 'package:geolocator/geolocator.dart';

import '../data/localizacao_mercados.dart';
import 'api_client.dart';

Future<Position?> obterPosicao({
  Future<void> Function()? aoNegarPermanentemente,
}) async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;

  var permissao = await Geolocator.checkPermission();
  if (permissao == LocationPermission.denied) {
    permissao = await Geolocator.requestPermission();
  }

  if (permissao == LocationPermission.deniedForever) {
    await aoNegarPermanentemente?.call();
    return null;
  }
  if (permissao == LocationPermission.denied) return null;

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );
}

List<MercadoProximo> mercadosProximos(
  Position pos,
  List<Market> mercados, {
  double raioKm = 15,
}) {
  final proximos = <MercadoProximo>[];
  for (final mercado in mercados) {
    final coordenadas = coordenadasMercados[mercado.id];
    if (coordenadas == null || coordenadas.isEmpty) continue;
    final distanciaKm = coordenadas
        .map(
          (coordenada) =>
              Geolocator.distanceBetween(
                pos.latitude,
                pos.longitude,
                coordenada.lat,
                coordenada.lng,
              ) /
              1000,
        )
        .reduce((menor, distancia) => distancia < menor ? distancia : menor);
    if (distanciaKm <= raioKm) {
      proximos.add(
        MercadoProximo(mercado: mercado, distanciaKm: distanciaKm),
      );
    }
  }
  proximos.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
  return proximos;
}
