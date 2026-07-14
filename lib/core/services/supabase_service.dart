import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupabaseService {
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {
      // Env file not found or failed to load, proceed in mock mode
    }
    
    final url = dotenv.isInitialized ? (dotenv.env['SUPABASE_URL'] ?? '') : '';
    final anonKey = dotenv.isInitialized ? (dotenv.env['SUPABASE_ANON_KEY'] ?? '') : '';
    
    if (url.isNotEmpty && 
        anonKey.isNotEmpty && 
        !url.contains('your-project.supabase.co')) {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
    }
  }

  SupabaseClient get client => Supabase.instance.client;
}

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final isMockModeProvider = Provider<bool>((ref) {
  final url = dotenv.isInitialized ? (dotenv.env['SUPABASE_URL'] ?? '') : '';
  final anonKey = dotenv.isInitialized ? (dotenv.env['SUPABASE_ANON_KEY'] ?? '') : '';
  return url.isEmpty || 
         anonKey.isEmpty || 
         url.contains('your-project.supabase.co') || 
         anonKey.contains('your-mock-key');
});
