import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'home.dart';

Future<Map<String, String>> authHeaders() async {
  final token = await storage.read(key: 'token');
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final searchController = TextEditingController();
  List users = [];
  String message = '';

  @override
  void initState() {
    super.initState();
    fetchUsers('');
  }

  Future<void> fetchUsers(String query) async {
    final headers = await authHeaders();
    final uri = Uri.parse('$apiUrl/friends/search')
        .replace(queryParameters: query.isNotEmpty ? {'q': query} : {});

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      setState(() {
        users = json.decode(response.body);
        message = '';
      });
    } else {
      setState(() => message = 'Erreur lors de la recherche');
    }
  }

  Future<void> sendRequest(int userId) async {
    final headers = await authHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/friends/$userId/request'),
      headers: headers,
    );

    if (response.statusCode == 201) {
      setState(() => message = 'Demande envoyée !');
    } else {
      final data = json.decode(response.body);
      setState(() => message = data['error'] ?? 'Erreur');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chercher des amis'),  backgroundColor: Colors.blue,
          foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher par email',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => fetchUsers(searchController.text),
                ),
              ),
              onSubmitted: fetchUsers,
            ),
            const SizedBox(height: 8),
            if (message.isNotEmpty)
              Text(message, style: const TextStyle(color: Colors.blue)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(user['email']),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: () => sendRequest(user['id']),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({super.key});

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  List friends = [];
  String message = '';

  @override
  void initState() {
    super.initState();
    fetchFriends();
  }

  Future<void> fetchFriends() async {
    final headers = await authHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/friends'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      setState(() => friends = json.decode(response.body));
    } else {
      setState(() => message = 'Erreur lors du chargement');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes amis'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white),
      body: message.isNotEmpty
          ? Center(child: Text(message))
          : friends.isEmpty
          ? const Center(child: Text('Aucun ami pour le moment'))
          : ListView.builder(
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return ListTile(
            leading: const Icon(Icons.person),
            title: Text(friend['email']),
          );
        },
      ),
    );
  }
}


class PendingRequestsPage extends StatefulWidget {
  const PendingRequestsPage({super.key});

  @override
  State<PendingRequestsPage> createState() => _PendingRequestsPageState();
}

class _PendingRequestsPageState extends State<PendingRequestsPage> {
  List requests = [];
  String message = '';

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    final headers = await authHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/friends/requests'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      setState(() => requests = json.decode(response.body));
    } else {
      setState(() => message = 'Erreur lors du chargement');
    }
  }

  Future<void> acceptRequest(int userId) async {
    final headers = await authHeaders();
    final response = await http.put(
      Uri.parse('$apiUrl/friends/$userId/accept'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      setState(() => message = 'Demande acceptée !');
      fetchRequests();
    } else {
      setState(() => message = 'Erreur lors de l\'acceptation');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demandes reçues'),  backgroundColor: Colors.blue,
          foregroundColor: Colors.white),
      body: Column(
        children: [
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(message, style: const TextStyle(color: Colors.green)),
            ),
          Expanded(
            child: requests.isEmpty
                ? const Center(child: Text('Aucune demande en attente'))
                : ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];
                return ListTile(
                  leading: const Icon(Icons.person_add),
                  title: Text(req['from']['email']),
                  trailing: IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => acceptRequest(req['from']['id']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
