import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'register.dart';
import 'login.dart';
import 'friendship.dart';
import 'podcast.dart';
import 'history.dart';
import 'recommendations.dart';

final storage = FlutterSecureStorage();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoggedIn = false;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    final token = await storage.read(key: 'token');
    final email = await storage.read(key: 'email');
    setState(() => isLoggedIn = token != null);
  }

  Future<void> logout() async {
    await storage.delete(key: 'token');
    await storage.delete(key: 'email');
    setState(() => isLoggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PodFriends'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (isLoggedIn) ...[
            Center(
              child: Text(
                userEmail ?? '',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: logout,
              child: const Text(
                'Se déconnecter',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
      body: Center(
        child: isLoggedIn
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              label: const Text('Chercher des amis'),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SearchUsersPage())),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              label: const Text('Mes amis'),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FriendsListPage())),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              label: const Text('Demandes reçues'),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PendingRequestsPage())),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              label: const Text('Podcasts'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PodcastSearchPage()),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              label: const Text('Mon historique'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              label: const Text('Mes recommandations'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecommendationsPage()),
              ),
            ),


          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterPage()),
              ),
              child: const Text('Register'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
                checkLogin();
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
