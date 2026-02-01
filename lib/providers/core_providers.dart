import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/datasources/supabase_datasource.dart';
import '../data/repositories/usuario_repository.dart';
import '../data/repositories/gabinete_repository.dart';
import '../data/repositories/cidadao_repository.dart';
import '../data/repositories/cadastro_repository.dart';
import '../data/repositories/solicitacao_repository.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/mensagem_repository.dart';
import '../data/repositories/atendimento_repository.dart';
import '../data/repositories/categoria_repository.dart';
import '../data/repositories/transmissao_repository.dart';
import '../data/services/uazapi_service.dart';
import '../data/services/storage_service.dart';
import '../data/models/usuario.dart';
import '../data/models/gabinete.dart';

// ============================================
// CORE PROVIDERS
// ============================================

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Supabase datasource provider
final supabaseDatasourceProvider = Provider<SupabaseDatasource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseDatasource(client);
});

// ============================================
// REPOSITORY PROVIDERS
// ============================================

final usuarioRepositoryProvider = Provider<UsuarioRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return UsuarioRepository(datasource);
});

final gabineteRepositoryProvider = Provider<GabineteRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return GabineteRepository(datasource);
});

final cidadaoRepositoryProvider = Provider<CidadaoRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return CidadaoRepository(datasource);
});

final cadastroRepositoryProvider = Provider<CadastroRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return CadastroRepository(datasource);
});

final solicitacaoRepositoryProvider = Provider<SolicitacaoRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return SolicitacaoRepository(datasource);
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return DashboardRepository(datasource);
});

final mensagemRepositoryProvider = Provider<MensagemRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return MensagemRepository(datasource);
});

final atendimentoRepositoryProvider = Provider<AtendimentoRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return AtendimentoRepository(datasource);
});

final categoriaRepositoryProvider = Provider<CategoriaRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return CategoriaRepository(datasource);
});

final transmissaoRepositoryProvider = Provider<TransmissaoRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return TransmissaoRepository(datasource);
});

// ============================================
// EXTERNAL SERVICES
// ============================================

/// UazAPI Service provider
final uazapiServiceProvider = Provider<UazapiService>((ref) {
  return UazapiService();
});

/// Storage Service provider for Supabase Storage
final storageServiceProvider = Provider<StorageService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StorageService(client);
});

// ============================================
// AUTH PROVIDERS
// ============================================

/// Auth state stream provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Current user session provider
final sessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final session = ref.watch(sessionProvider);
  return session != null;
});

// ============================================
// USER DATA PROVIDERS (CACHED)
// ============================================

/// Current user provider - CACHED
/// This replaces the multiple FutureBuilders for user data
final currentUserProvider = FutureProvider<Usuario?>((ref) async {
  final isAuth = ref.watch(isAuthenticatedProvider);
  if (!isAuth) return null;
  
  final repository = ref.watch(usuarioRepositoryProvider);
  return repository.getCurrentUser();
});

/// Current gabinete provider - CACHED
/// This replaces the multiple FutureBuilders for gabinete data
final currentGabineteProvider = FutureProvider<Gabinete?>((ref) async {
  final isAuth = ref.watch(isAuthenticatedProvider);
  if (!isAuth) return null;
  
  final repository = ref.watch(gabineteRepositoryProvider);
  return repository.getCurrentUserGabinete();
});

// ============================================
// NOTIFIERS FOR STATE MANAGEMENT
// ============================================

/// Auth notifier for login/logout actions
class AuthNotifier extends StateNotifier<AsyncValue<Session?>> {
  final SupabaseClient _client;
  final Ref _ref;

  AuthNotifier(this._client, this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    final session = _client.auth.currentSession;
    state = AsyncValue.data(session);
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = AsyncValue.data(response.session);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signOut();
      
      // Clear all caches
      _ref.read(usuarioRepositoryProvider).clearCache();
      _ref.read(gabineteRepositoryProvider).clearCache();
      _ref.read(cidadaoRepositoryProvider).clearCache();
      _ref.read(dashboardRepositoryProvider).clearCache();
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<Session?>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthNotifier(client, ref);
});
