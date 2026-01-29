import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../data/meditation_resources.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// Web-specific imports (only available on web)
import 'dart:html' as html show IFrameElement;
import 'dart:ui_web' as ui_web;

class MeditationPlayerScreen extends StatefulWidget {
  final MeditationResource meditation;

  const MeditationPlayerScreen({
    super.key,
    required this.meditation,
  });

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
        ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';
      
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
      
      _youtubeController = YoutubePlayerController(
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
              SizedBox(height: 16),
              Text(
                'Loading meditation video...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
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
      appBar: AppBar(
        title: Text(widget.meditation.title),
        backgroundColor: Colors.purple[50],
        foregroundColor: Colors.purple[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Video Player - Expanded to take available space but maintain aspect ratio
            Expanded(
              flex: 2,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildVideoPlayer(),
              ),
            ),
            
            // Meditation Info - Scrollable content
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16,
                ),
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
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[900],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.purple[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.meditation.category,
                              style: TextStyle(
                                color: Colors.purple[900],
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
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${widget.meditation.duration} minutes',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.meditation.description,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.purple[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              kIsWeb
                                  ? 'This meditation is playing directly in the app using an embedded player. You can control playback using the video controls.'
                                  : 'This meditation is playing directly in the app. You can control playback using the video controls.',
                              style: TextStyle(
                                color: Colors.purple[900],
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
          ],
        ),
      ),
    );
  }
}
