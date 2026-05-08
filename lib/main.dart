// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nhre/models/user_model.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/role_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth provider will manage user state globally
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Lesotho EHR System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
        ),
        
        home: const SetupScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) {
        
            final args = ModalRoute.of(context)!.settings.arguments as AppUser;
            return RoleSelectionScreen(user: args);
          },
        },
      ),
    );
  }
}
