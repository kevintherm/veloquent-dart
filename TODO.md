# VELOQUENT DART SDK TODO

## High Priority: Realtime Integration
- [ ] **Full WebSocket End-to-End Test**: The `test/integration_realtime_test.dart` currently uses `MockRealtimeAdapter` to simulate server-side events (`rtAdapter.emit`). While this verifies the SDK's internal orchestration (hitting `/subscribe` and wiring listeners), it does **not** test the actual network layer of a real WebSocket connection.
- [ ] **Native Integration**: Verify `Veloquent` with a real `PusherAdapter` or `SoketiAdapter` in a Flutter environment to ensure the native event loop correctly triggers the SDK's handlers.

## Record & Data Handling
- [ ] **Automatic Date Parsing**: Consider converting ISO strings in `Record` (like `created_at`) to `DateTime` objects automatically in the `Record` class.

## Low Priority
- [ ] Change email and change password requests.
