import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../data/meditation_resources.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

// Web-specific imports (only available on web)
import 'dart:html' as html show IFrameElement;
import 'dart:ui_web' as ui_web;

class MeditationPlayerScreen extends StatefulWidget {
  final MeditationResource meditation;

  const MeditationPlayerScreen({super.key, required this.meditation});

  @override
  State<MeditationPlayerScreen> createState() => _MeditationPlayerScreenState();
}

class _MeditationPlayerScreenState extends State<MeditationPlayerScreen> {
  YoutubePlayerController? _youtubeController;
  bool _isLoading = true;
  bool _isWeb = false;
  String? _iframeViewId;

  @override
  void initState() {
    super.initState();
    debugPrint('=== Meditation Player Screen Init ===');
    debugPrint('Meditation ID: ${widget.meditation.id}');
    debugPrint('Meditation Title: ${widget.meditation.title}');
    debugPrint('YouTube Video ID: ${widget.meditation.youtubeVideoId}');
    debugPrint('Embed URL: ${widget.meditation.embedUrl}');
    debugPrint('Platform: ${defaultTargetPlatform}');
    debugPrint('Is Web: $kIsWeb');

    _isWeb = kIsWeb;

    // Initialize based on platform
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) {
        _initializeWebPlayer();
      } else {
        _initializeMobilePlayer();
      }
    });
  }

  void _initializeWebPlayer() {
    if (!kIsWeb) return;

    try {
      debugPrint('=== Initializing Web Player (iframe) ===');

      // Generate unique view ID for iframe
      _iframeViewId = 'youtube-iframe-${widget.meditation.id}';

      // Create iframe element
      final iframe = html.IFrameElement()
        ..src = '${widget.meditation.embedUrl}?autoplay=1&rel=0&enablejsapi=1'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';

      // Register the iframe
      ui_web.platformViewRegistry.registerViewFactory(
        _iframeViewId!,
        (int viewId) => iframe,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      debugPrint('Web iframe player initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('=== ERROR in _initializeWebPlayer ===');
      debugPrint('Error: $e');
      debugPrint('Stack Trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize video player: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _initializeMobilePlayer() {
    try {
      debugPrint('=== Initializing Mobile Player (youtube_player_flutter) ===');

      _youtubeController =
          YoutubePlayerController(
            initialVideoId: widget.meditation.youtubeVideoId,
            flags: const YoutubePlayerFlags(
              autoPlay: true,
              mute: false,
              enableCaption: true,
              loop: false,
              isLive: false,
            ),
          )..addListener(() {
            if (_youtubeController!.value.isReady) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            }
          });

      debugPrint('Mobile YouTube player initialized successfully');

      // Set loading to false after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e, stackTrace) {
      debugPrint('=== ERROR in _initializeMobilePlayer ===');
      debugPrint('Error: $e');
      debugPrint('Stack Trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize video player: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                'Loading meditation video...',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (kIsWeb && _iframeViewId != null) {
      // Web: Use HtmlElementView for iframe
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: HtmlElementView(viewType: _iframeViewId!),
      );
    } else if (_youtubeController != null) {
      // Mobile: Use YoutubePlayer
      return YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.purple,
        progressColors: const ProgressBarColors(
          playedColor: Colors.purple,
          handleColor: Colors.purpleAccent,
          bufferedColor: Colors.purple,
          backgroundColor: Colors.grey,
        ),
      );
    } else {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Video player not available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('=== Building Meditation Player Screen ===');
    debugPrint('Is Loading: $_isLoading');
    debugPrint('Is Web: $_isWeb');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.meditation.title,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              debugPrint('Reload button pressed');
              if (kIsWeb) {
                _initializeWebPlayer();
              } else if (_youtubeController != null) {
                _youtubeController!.reload();
              }
            },
            tooltip: 'Reload',
          ),
        ],
      ),
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1593811167562-9cef47bfc4d7?auto=format&fit=crop&q=80',
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Video Player - Expanded to take available space but maintain aspect ratio
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 60,
                  ), // Add padding for transparent AppBar
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _buildVideoPlayer(),
                    ),
                  ),
                ),
              ),

              // Meditation Info - Scrollable content
              Expanded(
                flex: 3,
                child: GlassContainer(
                  margin: const EdgeInsets.only(top: 16),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  opacity: 0.1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title and Category
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.meditation.title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  widget.meditation.category,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Duration
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${widget.meditation.duration} minutes',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Description
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.meditation.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  kIsWeb
                                      ? 'This meditation is playing directly in the app using an embedded player. You can control playback using the video controls.'
                                      : 'This meditation is playing directly in the app. You can control playback using the video controls.',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
