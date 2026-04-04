import '../core/request.dart';

class Onboarding {
  Onboarding(this.requestHelper);

  final RequestHelper requestHelper;

  Future<bool> initialized() async {
    final result = await requestHelper.execute(
      method: 'POST',
      path: '/onboarding/initialized',
    );

    return result.data as bool;
  }

  Future<Map<String, dynamic>> createSuperuser(Map<String, dynamic> data) async {
    final result = await requestHelper.execute(
      method: 'POST',
      path: '/onboarding/superuser',
      body: data,
    );

    return Map<String, dynamic>.from(result.data);
  }
}
