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
