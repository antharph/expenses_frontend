import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthPage { login, register }

final authPageProvider = StateProvider<AuthPage>((ref) => AuthPage.login);
