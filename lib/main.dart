import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase & load Env variables
  await SupabaseService.initialize();

  runApp(
    const ProviderScope(
      child: EvidenceHubApp(),
    ),
  );
}
