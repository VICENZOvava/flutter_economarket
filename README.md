# EconoMarket Flutter

O aplicativo consome a API em `https://api-econo-market.vercel.app/api`. Para usar outra instância, configure o endereço com `--dart-define=API_BASE_URL=URL_DA_API`.

No Flutter, use `flutter pub get` e depois `flutter run`. Para desenvolvimento local, configure a URL da API local:

```sh
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
```

O usuário precisa se cadastrar ou entrar pela API. Listas e itens são associados ao token da sessão. Produtos, mercados e promoções exibem os registros existentes no banco conectado à API; telas sem dados mostram estados vazios.
