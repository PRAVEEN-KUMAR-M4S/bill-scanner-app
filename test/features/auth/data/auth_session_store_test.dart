import 'package:bill_scanner/features/auth/data/models/auth_tokens.dart';
import 'package:bill_scanner/features/auth/data/session/auth_session_store.dart';
import 'package:bill_scanner/features/auth/data/session/auth_session_storage.dart';
import 'package:bill_scanner/features/auth/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthSessionStore', () {
    test(
      'the SharedPreferences implementation survives a new instance',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        final AuthSessionStore first = AuthSessionStore(
          storage: SharedPreferencesAuthSessionStorage(preferences),
        );
        const User user = User(
          id: '7',
          name: 'Asha Tiffins',
          email: 'asha@billo.app',
        );

        await first.save(
          const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
          user: user,
        );

        // A second read is what the next app launch does.
        final AuthSessionStore restored = AuthSessionStore(
          storage: SharedPreferencesAuthSessionStorage(
            await SharedPreferences.getInstance(),
          ),
        );
        await restored.restore();

        expect(restored.accessToken, 'access-1');
        expect(restored.refreshToken, 'refresh-1');
        expect(restored.user, user);
      },
    );

    test(
      'keeps the pair and profile in memory for the running session',
      () async {
        final AuthSessionStore store = AuthSessionStore();
        const User user = User(
          id: '7',
          name: 'Asha Tiffins',
          email: 'asha@billo.app',
        );

        await store.save(
          const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
          user: user,
        );

        expect(store.accessToken, 'access-1');
        expect(store.refreshToken, 'refresh-1');
        expect(store.user, user);
        expect(store.hasSession, isTrue);
        expect(store.isSignedIn, isTrue);
      },
    );

    test('restores the session into a fresh store', () async {
      final InMemoryAuthSessionStorage storage = InMemoryAuthSessionStorage();
      final AuthSessionStore first = AuthSessionStore(storage: storage);
      const User user = User(
        id: '7',
        name: 'Asha Tiffins',
        email: 'asha@billo.app',
      );
      await first.save(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
        user: user,
      );

      final AuthSessionStore restored = AuthSessionStore(storage: storage);
      await restored.restore();

      expect(restored.accessToken, 'access-1');
      expect(restored.refreshToken, 'refresh-1');
      expect(restored.user, user);
      expect(restored.hasSession, isTrue);
    });

    test('restores a guest session that has no tokens', () async {
      final InMemoryAuthSessionStorage storage = InMemoryAuthSessionStorage();
      final AuthSessionStore first = AuthSessionStore(storage: storage);
      const User guest = User(
        id: 'guest',
        name: 'Guest',
        email: '',
        isGuest: true,
      );
      await first.saveUser(guest);

      final AuthSessionStore restored = AuthSessionStore(storage: storage);
      await restored.restore();

      expect(restored.hasSession, isFalse);
      expect(restored.isSignedIn, isTrue);
      expect(restored.user?.isGuest, isTrue);
    });

    test('clearing removes the tokens and the profile from storage', () async {
      final InMemoryAuthSessionStorage storage = InMemoryAuthSessionStorage();
      final AuthSessionStore store = AuthSessionStore(storage: storage);
      await store.save(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
        user: const User(id: '7', name: 'Asha', email: 'asha@billo.app'),
      );

      await store.clear();

      final AuthSessionStore restored = AuthSessionStore(storage: storage);
      await restored.restore();
      expect(restored.hasSession, isFalse);
      expect(restored.isSignedIn, isFalse);
      expect(restored.accessToken, isNull);
      expect(restored.refreshToken, isNull);
      expect(restored.user, isNull);
    });

    test('a new store with empty storage is signed out', () async {
      final AuthSessionStore store = AuthSessionStore(
        storage: InMemoryAuthSessionStorage(),
      );
      await store.restore();

      expect(store.hasSession, isFalse);
      expect(store.isSignedIn, isFalse);
    });
  });
}
