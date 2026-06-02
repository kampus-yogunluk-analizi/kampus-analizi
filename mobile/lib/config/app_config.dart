class AppConfig {
  static const String apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '10.147.4.111:8000',
  );

  static const String apiBaseUrl = 'http://$apiHost';
  static const String websocketUrl = 'ws://$apiHost/ws';
}
