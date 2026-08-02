import 'package:veloquent_sdk/veloquent_sdk.dart';
// import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

void main() async {
  // Initialize SDK with default config
  final sdk = Veloquent(
    apiUrl: 'https://example.com',
  );

  print('Veloquent SDK Initialized: ${sdk.config.apiUrl}');
}
