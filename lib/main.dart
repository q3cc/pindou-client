import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'services/parser_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    PinDouApp(
      parserService: ParserService(baseUri: AppConfig.parserBaseUri),
    ),
  );
}
