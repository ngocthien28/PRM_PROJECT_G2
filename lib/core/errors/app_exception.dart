class AppException implements Exception {
  final String message;
  final String code;
  final Object? cause;
  const AppException(this.message, {this.code = 'unknown', this.cause});
  @override
  String toString() => message;
}
