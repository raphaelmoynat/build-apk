import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'main.dart';
import 'home.dart';

class PodcastSearchPage extends StatefulWidget {
  const PodcastSearchPage({super.key});

  @override
  State<PodcastSearchPage> createState() => _PodcastSearchPageState();
}

class _PodcastSearchPageState extends State<PodcastSearchPage> {
  final searchController = TextEditingController();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _playerSubscription;

  List episodes = [];
  bool isLoading = false;
  int? playingIndex;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _playerSubscription = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed) playingIndex = null;
      });
    });
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    _player.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> authHeaders() async {
    final token = await storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> saveToHistory(Map episode) async {
    try {
      final headers = await authHeaders();
      await http.post(
        Uri.parse('$apiUrl/podcast/listen'),
        headers: headers,
        body: json.encode({
          'trackId':          episode['trackId'].toString(),
          'collectionId':     episode['collectionId'].toString(),
          'trackName':        episode['trackName'] ?? '',
          'shortDescription': episode['shortDescription'] ?? episode['description'] ?? '',
          'artworkUrl':       episode['artworkUrl160'] ?? episode['artworkUrl60'] ?? '',
        }),
      );
    } catch (e) {
      debugPrint('Erreur saveToHistory: $e');
    }
  }

  Future<void> searchPodcasts(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { isLoading = true; episodes = []; });

    final uri = Uri.parse('https://itunes.apple.com/search').replace(
      queryParameters: {
        'term': query,
        'media': 'podcast',
        'entity': 'podcastEpisode',
        'limit': '15',
      },
    );

    final response = await http.get(uri);
    if (!mounted) return;
    final data = json.decode(response.body);
    setState(() { episodes = data['results'] ?? []; isLoading = false; });
  }

  Future<void> togglePlay(int index, String url) async {
    if (playingIndex == index) {
      isPlaying ? await _player.pause() : await _player.resume();
      return;
    }
    setState(() => playingIndex = index);
    await saveToHistory(episodes[index]);
    await _player.play(UrlSource(url));
  }

  Future<void> stopPlayer() async {
    await _player.stop();
    if (!mounted) return;
    setState(() { playingIndex = null; isPlaying = false; });
  }


  void openShareSheet(Map episode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SharePodcastSheet(episode: episode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Podcasts'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (isLoading) const LinearProgressIndicator(),
          Expanded(child: _buildEpisodeList()),
          if (playingIndex != null && playingIndex! < episodes.length)
            _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un podcast...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: searchPodcasts,
      ),
    );
  }

  Widget _buildEpisodeList() {
    if (episodes.isEmpty) {
      return const Center(
        child: Text('Rechercher un podcast', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final ep = episodes[index];
        final audioUrl = ep['episodeUrl'] ?? ep['previewUrl'];
        final artwork  = ep['artworkUrl160'] ?? ep['artworkUrl60'];
        final isCurrent = playingIndex == index;

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
                  ? Image.network(artwork, width: 56, height: 56, fit: BoxFit.cover)
                  : const Icon(Icons.podcasts, size: 56),
            ),
            title: Text(
              ep['trackName'] ?? 'Sans titre',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              ep['collectionName'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  tooltip: 'Recommander',
                  onPressed: () => openShareSheet(ep),
                ),
                if (audioUrl != null)
                  IconButton(
                    icon: Icon(
                      isCurrent && isPlaying ? Icons.pause_circle : Icons.play_circle,
                      size: 40,
                      color: Colors.blue,
                    ),
                    onPressed: () => togglePlay(index, audioUrl),
                  )
                else
                  const Icon(Icons.block, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniPlayer() {
    final ep = episodes[playingIndex!];
    final audioUrl = ep['episodeUrl'] ?? ep['previewUrl'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.blue),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ep['trackName'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: () => togglePlay(playingIndex!, audioUrl),
          ),
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.white),
            onPressed: stopPlayer,
          ),
        ],
      ),
    );
  }
}


class SharePodcastSheet extends StatefulWidget {
  final Map episode;
  const SharePodcastSheet({super.key, required this.episode});

  @override
  State<SharePodcastSheet> createState() => _SharePodcastSheetState();
}

class _SharePodcastSheetState extends State<SharePodcastSheet> {
  final messageController = TextEditingController();
  List friends = [];
  Map? selectedFriend;
  bool isLoadingFriends = true;
  bool isSending = false;
  String? feedback;

  @override
  void initState() {
    super.initState();
    fetchFriends();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> authHeaders() async {
    final token = await storage.read(key: 'token');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<void> fetchFriends() async {
    final response = await http.get(Uri.parse('$apiUrl/friends'), headers: await authHeaders());
    if (!mounted) return;
    setState(() {
      friends = response.statusCode == 200 ? json.decode(response.body) : [];
      isLoadingFriends = false;
    });
  }

  Future<void> sendRecommendation() async {
    if (selectedFriend == null) {
      setState(() => feedback = 'Sélectionne un ami');
      return;
    }
    setState(() { isSending = true; feedback = null; });

    final ep = widget.episode;
    final response = await http.post(
      Uri.parse('$apiUrl/recommendations/send'),
      headers: await authHeaders(),
      body: json.encode({
        'receiverId':       selectedFriend!['id'],
        'trackId':          ep['trackId'].toString(),
        'collectionId':     ep['collectionId'].toString(),
        'trackName':        ep['trackName'] ?? '',
        'shortDescription': ep['shortDescription'] ?? ep['description'] ?? '',
        'artworkUrl':       ep['artworkUrl160'] ?? ep['artworkUrl60'] ?? '',
        'message':          messageController.text.trim(),
      }),
    );

    if (!mounted) return;
    setState(() => isSending = false);

    if (response.statusCode == 201) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Envoyé à ${selectedFriend!['email']}'),
        backgroundColor: Colors.blue,
      ));
    } else {
      String err = 'Erreur ${response.statusCode}';
      try { err = json.decode(response.body)['error'] ?? err; } catch (_) {}
      setState(() => feedback = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            widget.episode['trackName'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          if (isLoadingFriends)
            const CircularProgressIndicator()
          else if (friends.isEmpty)
            const Text('Aucun ami', style: TextStyle(color: Colors.grey))
          else
            DropdownButtonFormField<Map>(
              value: selectedFriend,
              hint: const Text('Choisir un ami'),
              items: friends.map((f) => DropdownMenuItem<Map>(
                value: f,
                child: Text(f['email']),
              )).toList(),
              onChanged: (v) => setState(() => selectedFriend = v),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

          const SizedBox(height: 12),

          TextField(
            controller: messageController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Message',
              border: OutlineInputBorder(),
            ),
          ),

          if (feedback != null) ...[
            const SizedBox(height: 8),
            Text(feedback!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSending ? null : sendRecommendation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(isSending ? 'Envoi...' : 'Envoyer'),
            ),
          ),
        ],
      ),
    );
  }
}
