import '../adapters/http/types.dart';
import '../adapters/realtime/types.dart';
import '../adapters/storage/types.dart';
import '../modules/auth.dart';
import '../modules/collections.dart';
import '../modules/onboarding.dart';
import '../modules/realtime.dart';
import '../modules/records.dart';
import '../modules/schema.dart';
import 'config.dart';
import 'request.dart';

class Veloquent {
  Veloquent({
    required String apiUrl,
    required HttpAdapter? http,
    required StorageAdapter? storage,
    RealtimeAdapter? realtime,
    Duration timeout = VeloquentConfig.defaultTimeout,
    int retryAttempts = VeloquentConfig.defaultRetryAttempts,
  }) : this.fromConfig(
          VeloquentConfig.validate(
            apiUrl: apiUrl,
            http: http,
            storage: storage,
            realtime: realtime,
            timeout: timeout,
            retryAttempts: retryAttempts,
          ),
        );

  Veloquent.fromConfig(this.config) {
    requestHelper = RequestHelper(config);
    auth = Auth(requestHelper);
    records = Records(requestHelper);
    collections = Collections(requestHelper);
    schema = Schema(requestHelper);
    onboarding = Onboarding(requestHelper);
    realtime = Realtime(requestHelper, config.realtime);
  }

  final VeloquentConfig config;
  late final RequestHelper requestHelper;

  late final Auth auth;
  late final Records records;
  late final Collections collections;
  late final Schema schema;
  late final Onboarding onboarding;
  late final Realtime realtime;
}
