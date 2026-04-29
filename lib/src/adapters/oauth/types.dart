/// Platform adapter for opening the OAuth URL and returning the exchange code.
///
/// The SDK calls this with the redirect URL. The launcher is responsible for:
/// 1. Opening the URL (e.g., via `url_launcher`, a WebView, or Chrome Custom Tabs).
/// 2. Waiting for the app's deep link / callback with `?code=` in the URI.
/// 3. Returning only the exchange code string.
typedef OAuthLauncher = Future<String> Function(String url);
