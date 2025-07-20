import 'package:flutter/material.dart';
import 'core/routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://hatscaabqgcrvrxxszco.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhhdHNjYWFicWdjcnZyeHhzemNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI4NzY0NjUsImV4cCI6MjA2ODQ1MjQ2NX0.8CuATKgehBR0tt2gaHM4MZrqywj0dXmBk3KpGi_-bSI',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rakib',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF32C156),
        ),
        useMaterial3: true,
      ),
      routes: appRoutes,
      initialRoute: '/home', // Changed from '/' to '/home'
    );
  }
}