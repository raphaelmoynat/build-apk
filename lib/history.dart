import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'main.dart';
import 'home.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List history    = [];
  bool isLoading  = false;
  String message  = '';
  int? playingIndex;
  bool isPlaying  = false;

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _playerSub;

  @override
  void initState() {
    super.initState();
    fetchHistory();

    _playerSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed) playingIndex = null;
      });
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.dispose();
    super.dispose();
  }


  Future<Map<String, String>> get _headers async {
    final token = await storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _setError(String msg) => setState(() => message = msg);

  // charge l'historique depuis l'API
  Future<void> fetchHistory() async {
    setState(() { isLoading = true; message = ''; });

    final response = await http.get(
      Uri.parse('$apiUrl/podcast/history'),
      headers: await _headers,
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      setState(() {
        history   = json.decode(response.body);
        isLoading = false;
      });
    } else {
      setState(() {
        message   = 'Erreur ${response.statusCode}';
        isLoading = false;
      });
    }
  }

  // récupère l'URL audio depuis l'api puis lance la lecture
  Future<void> relistenPodcast(int index, String trackId) async {
    final response = await http.get(
      Uri.parse('$apiUrl/podcast/relisten/$trackId'),
      headers: await _headers,
    );

    if (!mounted) return;

    if (response.statusCode != 200) {
      _setError('Impossible de récupérer l\'épisode');
      return;
    }

    final episodeUrl = json.decode(response.body)['episodeUrl'];

    if (episodeUrl == null) {
      _setError('Aucun fichier audio disponible');
      return;
    }

    await _togglePlay(index, episodeUrl);
  }

  Future<void> _togglePlay(int index, String url) async {
    if (playingIndex == index) {
      isPlaying ? await _player.pause() : await _player.resume();
      return;
    }
    setState(() => playingIndex = index);
    await _player.play(UrlSource(url));
  }

  Future<void> _stopPlayer() async {
    await _player.stop();
    if (!mounted) return;
    setState(() { playingIndex = null; isPlaying = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mon historique'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchHistory),
        ],
      ),
      body: Column(
        children: [
          if (isLoading) const LinearProgressIndicator(),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(message, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(child: _buildList()),
          if (playingIndex != null && playingIndex! < history.length)
            _buildMiniPlayer(),
        ],
      ),
    );
  }

  // liste des épisodes
  Widget _buildList() {
    if (!isLoading && history.isEmpty) {
      return const Center(
        child: Text('Aucun podcast écouté pour le moment',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: history.length,
      itemBuilder: (context, index) => _buildCard(index),
    );
  }

  // carte d'un épisode
  Widget _buildCard(int index) {
    final entry      = history[index];
    final podcast    = entry['podcast'];
    final isCurrent  = playingIndex == index;
    final artwork   = podcast['artworkUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent ? Border.all(color: Colors.blue, width: 1.5) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: _podcastIcon(artwork),
        title: Text(
          podcast['trackName'] ?? 'Sans titre',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          'Écouté le ${entry['listenedAt'] ?? ''}',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        trailing: IconButton(
          icon: Icon(
            isCurrent && isPlaying ? Icons.pause_circle : Icons.play_circle,
            size: 40,
            color: Colors.blue,
          ),
          onPressed: () => relistenPodcast(index, podcast['trackId'].toString()),
        ),
      ),
    );
  }

  // icon  podcast
  Widget _podcastIcon(String? artworkUrl) {
    if (artworkUrl != null && artworkUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          artworkUrl,
          width: 56, height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() => Container(
    width: 56, height: 56,
    decoration: BoxDecoration(
      color: Colors.blue.shade100,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.podcasts, color: Colors.blue, size: 30),
  );

  // barre de lecture en bas
  Widget _buildMiniPlayer() {
    final podcast = history[playingIndex!]['podcast'];
    final trackId = podcast['trackId'].toString();

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
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white),
            onPressed: () => relistenPodcast(playingIndex!, trackId),
          ),
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.white),
            onPressed: _stopPlayer,
          ),
        ],
      ),
    );
  }
}
