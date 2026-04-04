/// Apex API Configuration — change this for different environments
class ApiConfig {
  // Production
  static const String production = 'https://apex-api-ootk.onrender.com';

  // Local development
  static const String local = 'http://localhost:8080';

  // Active API URL — switch between production and local here
  static const String baseUrl = production;
}
