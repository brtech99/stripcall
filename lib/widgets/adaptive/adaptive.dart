/// Adaptive widgets that automatically use the appropriate
/// platform-specific widget (Material or Cupertino).
///
/// Usage:
/// ```dart
/// import 'package:stripcall/widgets/adaptive/adaptive.dart';
///
/// AppButton(onPressed: () {}, child: Text('Press me'))
/// AppTextField(controller: ctrl, label: 'Email')
/// AppScaffold(title: 'Page', body: content)
/// ```
library adaptive;

export 'app_button.dart';
export 'app_card.dart';
export 'app_dialog.dart';
export 'app_list_tile.dart';
export 'app_loading.dart';
export 'app_scaffold.dart';
export 'app_text_field.dart';
export 'app_dropdown.dart';
