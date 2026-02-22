import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'backend/auth/services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/navigation/main_navigation_screen.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthServiceProvider()),
        Provider<AuthService>(create: (_) => AuthService.instance),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Still waiting for the persisted session to be restored
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // Signed in → main app
            if (snapshot.hasData && snapshot.data != null) {
              return const MainNavigationScreen();
            }
            // Not signed in → login
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

// ChangeNotifier wrapper for AuthService to enable state updates
class AuthServiceProvider extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}
