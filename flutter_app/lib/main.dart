import 'package:flutter/material.dart';

import 'src/chess_money_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await ChessMoneyApp.create());
}
