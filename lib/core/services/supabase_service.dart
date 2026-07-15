import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupabaseService {
  static const String _url = 'https://fkoetkedavhbsrukynhq.supabase.co';
  static const String _anonKey = 'sb_publishable_z8hkMH7w9U5JgcJpTb3ZOw_A8-0ekMi';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;
}

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});
