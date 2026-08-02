## 1.7.3

- **Dependencies**:
    - Upgraded `flutter_secure_storage` to `^10.3.1`.

## 1.0.0

- Initial version.

## 1.0.1

- Removed unnecessary files.

## 1.0.2

- Fix auth.login module, change email field to identity.

## 1.1.0

- Add support for multipart/form-data file uploads in records module.

## 1.1.1

- Update installation docs

## 1.2.0

- **Auth**: 
    - Added synchronous `.user` and `.session` getters for immediate access to last-fetched data.
    - Added `loadState()` to restore authentication state from persistence.
    - FIXED: Changed `logout` method from `POST` to `DELETE` to match server requirements.
- **Storage**:
    - Added `SecureStorageAdapter` as a drop-in wrapper for `flutter_secure_storage`.
    - Renamed `LocalStorageAdapter` to `SharedPreferencesAdapter` for clarity.
    - Removed generic `AsyncStorageAdapter`.
- Added `onPrepareMultipart` hook to `HttpRequest` to allow manual header injection (e.g. `Host` header for local development).
- Added `getFieldErrors(field)` and `getFirstFieldError(field)` to `SdkError` for easier validation error mapping.
- Refactored exports in `veloquent_sdk.dart` for better indexing and autocompletion.
- Removed unused `veloquent_sdk_base.dart` placeholder.

## 1.2.1

- Update readme

## 1.3.0

- **Auth**: 
    - Add OAuth2 authentication support
    
## 1.3.1

- **Utility**:
    - Error getters now follow the new server error responses

## 1.4.0

- **AI Chat Module**:
    - Added the `Ai` module supporting normal chat (`chat()`) and streaming chat (`chatStream()`) requests.
    - Implemented streaming SSE (Server-Sent Events) via a new `requestStream()` byte-streaming method in `HttpAdapter` and `FetchAdapter`.
    - Enforced that the `collection` parameter is required for all AI chat methods, emphasizing that agent collections are user-defined.

## 1.5.0

- **New Login Alert**:
    - Attached device id and user agent if available on requests for Veloquent to detect new login from different source.

## 1.7.1

- **Fix**:
    - Resolve issue where optimistic cache updates fail for wrapped response formats (e.g. nested under `data` or `items`).

## 1.7.0

- **Caching Adapter**:
    - Implemented `CachingAdapter` to cache `GET` responses with customizable TTL.
    - Added offline fallback read support from cache on network errors.
    - Added optimistic cache updates for `POST`, `PATCH`, and `DELETE` requests that return synthetic 202 status codes.
    - Added cache invalidation registry to automatically clear collection caches when online mutations succeed.

## 1.6.0

- **Offline Support**:
    - Implemented a plug-and-play `OfflineAdapter` that wraps any `HttpAdapter`.
    - Automatically queues `POST`, `PATCH`, and `DELETE` requests during network failures.
    - Replays queued requests in FIFO order when connectivity is restored.
    - Exposes callbacks `onQueued`, `onFlushed`, and `onFlushError` for custom event handling.
    - Automatically refreshes the auth token from storage during replay.

## 1.5.1

- **Fix**:
    - Resolve date/datetime serialization issues and enforce UTC timezone parsing for timezone-less datetime strings.

## 1.6.1

- **Fix**:
    - Standardize DateTime serialization/deserialization for locally stored states (user records and auth metadata) to avoid `jsonEncode` crashes.

## 1.7.2

- **Optimization**:
    - Trigger immediate `flush()` of offline mutation queue on new HTTP requests if the queue is non-empty, reducing the data staleness window upon network recovery.
