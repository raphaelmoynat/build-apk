import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';

class PodcastSearchPage extends StatefulWidget {
  const PodcastSearchPage({super.key});

  @override
  State<PodcastSearchPage> createState() => _PodcastSearchPageState();
}

class _PodcastSearchPageState extends State<PodcastSearchPage> {
  final searchController = TextEditingController();
  final AudioPlayer _player = AudioPlayer();

  List episodes = [];
  bool isLoading = false;
  int? playingIndex;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      setState(() {
        isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed) {
          playingIndex = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> searchPodcasts(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      isLoading = true;
      episodes = [];
    });

    final uri = Uri.parse('https://itunes.apple.com/search').replace(
      queryParameters: {
        'term': query,
        'media': 'podcast',
        'entity': 'podcastEpisode',
        'limit': '15',
      },
    );

    final response = await http.get(uri);
    final data = json.decode(response.body);

    setState(() {
      episodes = data['results'] ?? [];
      isLoading = false;
    });
  }

  Future<void> togglePlay(int index, String url) async {
    if (playingIndex == index) {
      isPlaying ? await _player.pause() : await _player.resume();
      return;
    }
    setState(() => playingIndex = index);
    await _player.play(UrlSource(url));
  }

  Future<void> stopPlayer() async {
    await _player.stop();
    setState(() {
      playingIndex = null;
      isPlaying = false;
    });
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
          if (playingIndex != null && playingIndex! < episodes.length) _buildMiniPlayer(),
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
        child: Text(
          'Rechercher un podcast',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final ep = episodes[index];
        final audioUrl = ep['episodeUrl'] ?? ep['previewUrl'];
        final artwork = ep['artworkUrl160'] ?? ep['artworkUrl60'];
        final isCurrent = playingIndex == index;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isCurrent ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isCurrent
                ? Border.all(color: Colors.blue, width: 1.5)
                : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),

            // 🖼️ Image
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

            trailing: audioUrl != null
                ? IconButton(
              icon: Icon(
                isCurrent && isPlaying ? Icons.pause_circle : Icons.play_circle,
                size: 40,
                color: Colors.blue,
              ),
              onPressed: () => togglePlay(index, audioUrl),
            )
                : const Icon(Icons.block, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildMiniPlayer() {
    if (playingIndex == null || playingIndex! >= episodes.length) {
      return const SizedBox.shrink();
    }

    final ep = episodes[playingIndex!];
    final audioUrl = ep['episodeUrl'] ?? ep['previewUrl'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.blue,
      ),
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
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () => togglePlay(playingIndex!, audioUrl),
          ),
        ],
      ),
    );
  }

}
