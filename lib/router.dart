import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ui/pages/auth/login_page.dart';
import 'ui/pages/auth/criar_conta_page.dart';
import 'ui/pages/home/home_page.dart';
import 'ui/pages/solicitacoes/solicitacoes_page.dart';
import 'ui/pages/cidadaos/cidadaos_page.dart';
import 'ui/pages/mensagens/mensagens_page.dart';
import 'ui/pages/atividades/atividades_page.dart';
import 'ui/pages/dev/integration_test_page.dart';
import 'ui/pages/campanhas_whatsapp_page.dart';
import 'ui/pages/assessores_page.dart';
import 'ui/pages/perfil/perfil_page.dart';
import 'ui/pages/notificacoes/notificacoes_page.dart';
import 'ui/pages/cidadaos/cidadaos_map_page.dart';

/// Auth state for routing
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Listenable que notifica apenas em login/logout reais
class _AuthNotifier extends ChangeNotifier {
  Session? _lastSession;
  StreamSubscription<AuthState>? _subscription;

  _AuthNotifier() {
    _lastSession = Supabase.instance.client.auth.currentSession;
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      final newSession = authState.session;
      final wasLoggedIn = _lastSession != null;
      final isLoggedIn = newSession != null;

      // Só notifica se mudou de logado para deslogado ou vice-versa
      // Ignora mudanças de token refresh ou setSession com mesmo usuário
      if (wasLoggedIn != isLoggedIn) {
        _lastSession = newSession;
        notifyListeners();
      } else if (wasLoggedIn && isLoggedIn) {
        // Ambos logados - verifica se é mesmo usuário
        final sameUser = _lastSession?.user.id == newSession.user.id;
        if (!sameUser) {
          _lastSession = newSession;
          notifyListeners();
        }
        // Se é mesmo usuário, NÃO notifica (evita redirect indesejado)
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Singleton do notifier de auth
final _authNotifier = _AuthNotifier();

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;

      final isOnLogin = state.matchedLocation == '/login';
      final isOnCadastro = state.matchedLocation == '/criar-conta';
      final forceLogin = state.uri.queryParameters['force'] == 'true';

      if (!isAuthenticated && !isOnLogin && !isOnCadastro) {
        return '/login';
      }

      if (isAuthenticated && isOnLogin && !forceLogin) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: '/criar-conta',
        name: 'criar-conta',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const CriarContaPage(),
        ),
      ),

      // Main app routes
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const HomePage(),
        ),
      ),
      GoRoute(
        path: '/mensagens',
        name: 'mensagens',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const MensagensPage(),
        ),
      ),
      GoRoute(
        path: '/solicitacoes',
        name: 'solicitacoes',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const SolicitacoesPage(),
        ),
      ),
      GoRoute(
        path: '/cidadaos',
        name: 'cidadaos',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const CidadaosPage(),
        ),
      ),
      GoRoute(
        path: '/cidadaos/mapa',
        name: 'cidadaos-map',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const CidadaosMapPage(),
        ),
      ),

      // Placeholder routes - to be implemented
      GoRoute(
        path: '/atividades',
        name: 'atividades',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const AtividadesPage(),
        ),
      ),
      GoRoute(
        path: '/dev/tests',
        name: 'dev-tests',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const IntegrationTestPage(),
        ),
      ),
      GoRoute(
        path: '/transmissoes',
        name: 'transmissoes',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const CampanhasWhatsappPage(),
        ),
      ),
      GoRoute(
        path: '/acessores',
        name: 'acessores',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const AssessoresPage(),
        ),
      ),
      GoRoute(
        path: '/notificacoes',
        name: 'notificacoes',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const NotificacoesPage(),
        ),
      ),
      GoRoute(
        path: '/perfil',
        name: 'perfil',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const PerfilPage(),
        ),
      ),
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Página não encontrada',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(state.uri.toString()),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
