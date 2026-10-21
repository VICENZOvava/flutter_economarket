# EconoMarket Flutter

O aplicativo consome a API Node disponível na pasta web. O endereço padrão é `http://localhost:3000/api` para web, Windows, macOS e iOS Simulator; no emulador Android, é `http://10.0.2.2:3000/api`.

Para iniciar a API na pasta pai, execute `npm run dev`. No Flutter, use `flutter pub get` e depois `flutter run`.

Em um celular físico, configure o endereço do computador na mesma rede:

```sh
flutter run --dart-define=API_BASE_URL=http://IP_DO_COMPUTADOR:3000/api
```

O usuário precisa se cadastrar ou entrar pela API. Listas e itens são associados ao token da sessão. Produtos, mercados e promoções exibem os registros existentes no banco conectado à API; telas sem dados mostram estados vazios.
