enum Environment {
  dev,
  mobile,
  prod,
  mock, // For offline testing with mock data
}

class EnvironmentConfig {
  static Environment _environment = Environment.dev;
  static final Map<Environment, String> _baseUrls = {
    Environment.dev:
        'https://api.fanla.net',
    Environment.mobile:
        'https://api.fanla.net', // For Android emulator
    Environment.prod:
        'https://api.fanla.net',
    Environment.mock: '', // No URL for mock environment
  };

  // API request timeout in seconds
  static const int timeoutSeconds = 10;

  static void setEnvironment(Environment env) {
    _environment = env;
  }

  static Environment get environment => _environment;

  static String get baseUrl =>
      _baseUrls[_environment] ?? _baseUrls[Environment.dev]!;

  static String get apiUrl =>
      _environment == Environment.mock ? '' : '$baseUrl/api/fan';

  static String get wsUrl => _environment == Environment.mock
      ? ''
      : baseUrl.replaceFirst('http', 'ws');

  static bool get isMockEnvironment => _environment == Environment.mock;
}
