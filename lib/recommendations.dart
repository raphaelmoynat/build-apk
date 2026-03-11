import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'main.dart';
import 'home.dart';

Future<Map<String, String>> authHeaders() async {
  final token = await storage.read(key: 'token');
  return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
}

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List received = [];
  List sent     = [];
  bool isLoadingReceived = true;
  bool isLoadingSent     = true;

  // ── Player ────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _playerSub;
  int? playingIndex;
  String? playingTab; // 'received' ou 'sent'
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchReceived();
    fetchSent();

    _playerSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed) { playingIndex = null; playingTab = null; }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _playerSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> fetchReceived() async {
    setState(() => isLoadingReceived = true);
    final response = await http.get(
      Uri.parse('$apiUrl/recommendations/received'),
      headers: await authHeaders(),
    );
    if (!mounted) return;
    setState(() {
      received = response.statusCode == 200 ? json.decode(response.body) : [];
      isLoadingReceived = false;
    });
  }

  Future<void> fetchSent() async {
    setState(() => isLoadingSent = true);
    final response = await http.get(
      Uri.parse('$apiUrl/recommendations/sent'),
      headers: await authHeaders(),
    );
    if (!mounted) return;
    setState(() {
      sent = response.statusCode == 200 ? json.decode(response.body) : [];
      isLoadingSent = false;
    });
  }

  // Récupère l'URL puis joue
  Future<void> relistenPodcast(int index, String trackId, String tab) async {
    final response = await http.get(
      Uri.parse('$apiUrl/podcast/relisten/$trackId'),
      headers: await authHeaders(),
    );
    if (!mounted) return;
    if (response.statusCode != 200) return;

    final episodeUrl = json.decode(response.body)['episodeUrl'];
    if (episodeUrl == null) return;

    if (playingIndex == index && playingTab == tab) {
      isPlaying ? await _player.pause() : await _player.resume();
      return;
    }


    final list    = tab == 'sent' ? sent : received;
    final podcast = list[index]['podcast'];

    try {
      await http.post(
        Uri.parse('$apiUrl/podcast/listen'),
        headers: await authHeaders(),
        body: json.encode({
          'trackId':          podcast['trackId'].toString(),
          'collectionId':     podcast['collectionId']?.toString() ?? '',
          'trackName':        podcast['trackName'] ?? '',
          'shortDescription': podcast['shortDescription'] ?? '',
          'artworkUrl':       podcast['artworkUrl'] ?? '',
        }),
      );
    } catch (e) {
      debugPrint('Erreur saveToHistory: $e');
    }

    setState(() { playingIndex = index; playingTab = tab; });
    await _player.play(UrlSource(episodeUrl));
  }

  Future<void> stopPlayer() async {
    await _player.stop();
    if (!mounted) return;
    setState(() { playingIndex = null; playingTab = null; isPlaying = false; });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Podcast en cours selon l'onglet actif
    Map? currentPodcast;
    if (playingIndex != null) {
      final list = playingTab == 'sent' ? sent : received;
      if (playingIndex! < list.length) {
        currentPodcast = list[playingIndex!]['podcast'];
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Recommandations'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Reçues'),
            Tab(text: 'Envoyées'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTab(received, isLoadingReceived, 'received', fetchReceived),
                _buildTab(sent,     isLoadingSent,     'sent',     fetchSent),
              ],
            ),
          ),
          if (currentPodcast != null) _buildMiniPlayer(currentPodcast),
        ],
      ),
    );
  }

  Widget _buildTab(List list, bool loading, String tab, Future<void> Function() onRefresh) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) return Center(
      child: Text('Aucune recommandation', style: TextStyle(color: Colors.grey[400])),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final reco    = list[index];
          final podcast = reco['podcast'];
          final person  = tab == 'sent' ? reco['receiver'] : reco['sender'];
          final label   = tab == 'sent' ? 'À : ${person['email']}' : 'De : ${person['email']}';
          final isCurrent = playingIndex == index && playingTab == tab;

          return _buildCard(
            podcast:   podcast,
            label:     label,
            message:   reco['message'],
            sentAt:    reco['sentAt'] ?? '',
            isCurrent: isCurrent,
            onPlay:    () => relistenPodcast(index, podcast['trackId'].toString(), tab),
          );
        },
      ),
    );
  }

  Widget _buildCard({
    required Map podcast,
    required String label,
    required String? message,
    required String sentAt,
    required bool isCurrent,
    required VoidCallback onPlay,
  }) {
    final artwork = podcast['artworkUrl'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent ? Border.all(color: Colors.blue, width: 1.5) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: artwork != null
              ? Image.network(artwork, width: 56, height: 56, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback())
              : _fallback(),
        ),
        title: Text(
          podcast['trackName'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.blue)),
            if (message != null && message.isNotEmpty)
              Text('$message',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isCurrent && isPlaying ? Icons.pause_circle : Icons.play_circle,
            size: 40, color: Colors.blue,
          ),
          onPressed: onPlay,
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(Map podcast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.blue,
      child: Row(
        children: [
          Expanded(
            child: Text(
              podcast['trackName'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: () => relistenPodcast(
              playingIndex!,
              podcast['trackId'].toString(),
              playingTab!,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.white),
            onPressed: stopPlayer,
          ),
        ],
      ),
    );
  }

  Widget _fallback() => Container(
    width: 56, height: 56,
    decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.podcasts, color: Colors.blue, size: 30),
  );
}
