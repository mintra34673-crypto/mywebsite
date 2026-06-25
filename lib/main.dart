import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runZonedGuarded(
    () async {
      BindingBase.debugZoneErrorsAreFatal = true;
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await EasyLocalization.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrintStack(
          stackTrace: details.stack,
          label: 'Flutter Error: ${details.exception}',
        );
      };

      runApp(
        EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('th')],
          path: 'assets/translations',
          fallbackLocale: const Locale('th'),
          child: const MyApp(),
        ),
      );
    },
    (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace, label: 'Async Error: $error');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BinSort',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.pink),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
