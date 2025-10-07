  enum Environment {
    dev,
    prod,
  }

  class EnvironmentConfig {
    static Environment _environment = Environment.prod;

    static void setEnvironment(Environment env) {
      _environment = env;
    }

    static Environment get environment => _environment;

    static bool get isDev => _environment == Environment.dev;
    static bool get isProd => _environment == Environment.prod;

    static String get environmentName => _environment.toString().split('.').last;

    // Firebase project IDs
    static String get firebaseProjectId => isProd
        ? 'squad-7bc7e'
        : 'linkup-bu-test-environment';

    // Web app URLs for hangout invites
    static String get webAppUrl => isProd
        ? 'https://squad-7bc7e.web.app'
        : 'https://linkup-bu-test-environment.web.app';
  }