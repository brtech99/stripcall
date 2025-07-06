# Debug Logging System

This project uses a conditional debug logging system to help with troubleshooting while keeping production code clean.

## How to Use

### Enable Debug Logging
To enable debug logging, edit `lib/utils/debug_utils.dart` and change:
```dart
const bool kDebugLogging = false;
```
to:
```dart
const bool kDebugLogging = true;
```

### Disable Debug Logging
To disable debug logging, set:
```dart
const bool kDebugLogging = false;
```

## Available Functions

### `debugLog(String message)`
Prints a debug message with "DEBUG:" prefix when logging is enabled.

Example:
```dart
debugLog('Loading messages for problem ${problemId}');
```

### `debugLogError(String message, [Object? error])`
Prints a debug error message with "DEBUG ERROR:" prefix when logging is enabled.

Example:
```dart
debugLogError('Error loading messages', e);
```

## Benefits

1. **Conditional Compilation**: Debug messages are completely removed from production builds when `kDebugLogging = false`
2. **Easy Toggle**: Single flag to enable/disable all debug logging
3. **Consistent Format**: All debug messages follow the same format
4. **Future-Proof**: Easy to add new debug statements without cluttering production code

## Usage Guidelines

- Use `debugLog()` for informational messages
- Use `debugLogError()` for error messages
- Keep debug messages concise but informative
- Include relevant data (IDs, counts, etc.) in debug messages
- Don't log sensitive information (passwords, tokens, etc.)

## Example

```dart
import '../utils/debug_utils.dart';

Future<void> loadData() async {
  try {
    debugLog('Starting data load');
    final data = await fetchData();
    debugLog('Loaded ${data.length} items');
  } catch (e) {
    debugLogError('Failed to load data', e);
  }
} 