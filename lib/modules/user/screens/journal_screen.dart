import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/ai_service.dart';
import '../../../models/journal_entry_model.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String? _currentUserId;
  List<JournalEntryModel> _entries = [];
  List<JournalEntryModel> _filteredEntries = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedMoodFilter;
  bool _showEntryForm = false;
  final TextEditingController _contentController = TextEditingController();
  String _selectedMood = 'neutral';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _initializeAndLoadEntries();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoadEntries() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user != null) {
      setState(() => _currentUserId = user.id);
      // Load entries immediately
      await _loadEntries();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEntries() async {
    if (_currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final currentUser = authService.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final username = currentUser.name.toLowerCase().replaceAll(' ', '_');
      
      debugPrint('Loading journal entries from: $userNodePath/$username/journal_entries');
      final entriesData = await dbService.readList('$userNodePath/$username/journal_entries');
      debugPrint('Found ${entriesData.length} entries');
      
      final List<JournalEntryModel> loadedEntries = [];
      for (var data in entriesData) {
        try {
          // Convert LinkedMap to Map<String, dynamic> recursively
          dynamic convertValue(dynamic value) {
            if (value is Map) {
              return Map<String, dynamic>.from(
                value.map((key, val) => MapEntry(
                  key.toString(),
                  convertValue(val),
                )),
              );
            } else if (value is List) {
              return List<dynamic>.from(value.map((item) => convertValue(item)));
            }
            return value;
          }
          
          final Map<String, dynamic> entryMap = convertValue(data) as Map<String, dynamic>;
          final entry = JournalEntryModel.fromMap(entryMap);
          loadedEntries.add(entry);
        } catch (e) {
          debugPrint('Error parsing journal entry: $e');
          debugPrint('Entry data: $data');
          continue;
        }
      }
      
      // Sort entries by date (newest first)
      loadedEntries.sort((a, b) => b.date.compareTo(a.date));
      
      if (mounted) {
        setState(() {
          _entries = loadedEntries;
          _applyFilters();
          _isLoading = false;
        });
      }
      
      debugPrint('Successfully loaded ${loadedEntries.length} journal entries');
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading entries: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error loading journal entries: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredEntries = _entries.where((entry) {
        final matchesSearch = _searchQuery.isEmpty ||
            entry.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            entry.mood.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesMood = _selectedMoodFilter == null || entry.mood == _selectedMoodFilter;
        return matchesSearch && matchesMood;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Well-Being Journal'),
        backgroundColor: Colors.pink[50],
        foregroundColor: Colors.pink[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
          IconButton(
            icon: Icon(_showEntryForm ? Icons.close : Icons.add),
            onPressed: () {
              setState(() {
                _showEntryForm = !_showEntryForm;
                if (!_showEntryForm) {
                  _contentController.clear();
                  _selectedMood = 'neutral';
                  _selectedDate = DateTime.now();
                  _selectedTime = TimeOfDay.now();
                }
              });
            },
            tooltip: _showEntryForm ? 'Close Form' : 'New Entry',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEntries,
              child: CustomScrollView(
                slivers: [
                  // Entry Form (shown when _showEntryForm is true)
                  if (_showEntryForm)
                    SliverToBoxAdapter(
                      child: _buildEntryForm(),
                    ),
                  // Filter Chips
                  if (_searchQuery.isNotEmpty || _selectedMoodFilter != null)
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.pink[50],
                        child: Row(
                          children: [
                            if (_searchQuery.isNotEmpty)
                              Chip(
                                label: Text('Search: $_searchQuery'),
                                backgroundColor: Colors.pink[100],
                                deleteIconColor: Colors.pink[700],
                                onDeleted: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _applyFilters();
                                  });
                                },
                              ),
                            if (_selectedMoodFilter != null) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text('Mood: $_selectedMoodFilter'),
                                backgroundColor: Colors.pink[100],
                                deleteIconColor: Colors.pink[700],
                                onDeleted: () {
                                  setState(() {
                                    _selectedMoodFilter = null;
                                    _applyFilters();
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  // Journal Entries List or Empty State
                  if (_filteredEntries.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _entries.isEmpty
                                  ? 'No journal entries yet'
                                  : 'No entries match your filters',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            if (_entries.isEmpty)
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showEntryForm = true;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pink[600],
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Write Your First Entry'),
                              )
                            else
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedMoodFilter = null;
                                    _applyFilters();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pink[600],
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Clear Filters'),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: 16,
                      ),
                      sliver: _buildGroupedEntriesSliver(),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildEntryForm() {
    final moods = ['happy', 'sad', 'anxious', 'stressed', 'angry', 'neutral', 'depressed', 'overwhelmed'];

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.pink[50]!,
              Colors.pink[100]!,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.pink[700], size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'New Journal Entry',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink[900],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Date and Time Selection
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.pink[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Colors.pink[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Date & Time',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.pink[900],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Colors.pink[600]!,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black87,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (pickedDate != null) {
                                setState(() => _selectedDate = pickedDate);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.pink[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.pink[300]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.event, size: 18, color: Colors.pink[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                                    style: TextStyle(color: Colors.pink[900]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime,
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Colors.pink[600]!,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black87,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  _selectedTime = pickedTime;
                                  _selectedDate = DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month,
                                    _selectedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.pink[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.pink[300]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, size: 18, color: Colors.pink[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedTime.format(context),
                                    style: TextStyle(color: Colors.pink[900]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'How are you feeling?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[900],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: moods.map((mood) {
                  final isSelected = _selectedMood == mood;
                  return FilterChip(
                    label: Text(mood),
                    selected: isSelected,
                    selectedColor: Colors.pink[200],
                    checkmarkColor: Colors.pink[700],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.pink[900] : Colors.pink[700],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      setState(() => _selectedMood = mood);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: 'Write your thoughts...',
                  labelStyle: TextStyle(color: Colors.pink[700]),
                  hintText: 'Express your feelings, thoughts, or experiences...',
                  hintStyle: TextStyle(color: Colors.pink[300]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.pink[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.pink[600]!, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 6,
                autofocus: false,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showEntryForm = false;
                        _contentController.clear();
                        _selectedMood = 'neutral';
                        _selectedDate = DateTime.now();
                        _selectedTime = TimeOfDay.now();
                      });
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.pink[700]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (_contentController.text.trim().isNotEmpty) {
                        await _saveEntry(
                          _contentController.text.trim(),
                          _selectedMood,
                          _selectedDate,
                        );
                        setState(() {
                          _showEntryForm = false;
                          _contentController.clear();
                          _selectedMood = 'neutral';
                          _selectedDate = DateTime.now();
                          _selectedTime = TimeOfDay.now();
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Please write something before saving'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Save Entry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _saveEntry(String content, String mood, DateTime? customDate) async {
    if (_currentUserId == null) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final aiService = Provider.of<AIService>(context, listen: false);
      
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final currentUser = authService.currentUser;
      if (currentUser == null) return;

      final username = currentUser.name.toLowerCase().replaceAll(' ', '_');
      final selectedDate = customDate ?? DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

      // Check if journal entry already exists for this date
      try {
        final existingEntries = await dbService.readList('$userNodePath/$username/journal_entries');
        for (var entryData in existingEntries) {
          try {
            // Convert LinkedMap to Map<String, dynamic> recursively
            dynamic convertValue(dynamic value) {
              if (value is Map) {
                return Map<String, dynamic>.from(
                  value.map((key, val) => MapEntry(
                    key.toString(),
                    convertValue(val),
                  )),
                );
              } else if (value is List) {
                return value.map((item) => convertValue(item)).toList();
              }
              return value;
            }
            
            final Map<String, dynamic> entryMap = convertValue(entryData) as Map<String, dynamic>;
            final existingEntry = JournalEntryModel.fromMap(entryMap);
            final existingDateKey = DateFormat('yyyy-MM-dd').format(existingEntry.date);
            if (existingDateKey == dateKey) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('You already have a journal entry for ${DateFormat('MMM dd, yyyy').format(selectedDate)}. Only one entry per day is allowed.'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
          } catch (e) {
            continue;
          }
        }
      } catch (e) {
        // No existing entries, continue
      }

      final emotionAnalysis = await aiService.analyzeEmotions(
        content,
        _currentUserId!,
        null,
      );

      final moodScore = emotionAnalysis.overallScore;

      final entry = JournalEntryModel(
        id: const Uuid().v4(),
        userId: _currentUserId!,
        content: content,
        mood: mood,
        moodScore: moodScore,
        date: selectedDate,
        emotionAnalysis: emotionAnalysis.emotionScores,
        stressTriggers: emotionAnalysis.suggestedActions,
      );

      // Store under username
      final savePath = '$userNodePath/$username/journal_entries/${entry.id}';
      debugPrint('Saving journal entry to: $savePath');
      debugPrint('Entry data: ${entry.toMap()}');
      
      await dbService.writeData(
        savePath,
        entry.toMap(),
      );

      await dbService.pushData(
        '$userNodePath/$username/mood_analyses',
        emotionAnalysis.toMap(),
      );

      debugPrint('Journal entry saved successfully, reloading entries...');
      await _loadEntries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Journal entry saved for ${DateFormat('MMM dd, yyyy').format(selectedDate)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving journal entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving entry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showSearchDialog() async {
    final searchController = TextEditingController(text: _searchQuery);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Journal'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Search entries...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _applyFilters();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = searchController.text.trim();
                _applyFilters();
              });
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    final moods = ['happy', 'sad', 'anxious', 'stressed', 'angry', 'neutral', 'depressed', 'overwhelmed'];
    String? selectedMood = _selectedMoodFilter;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter by Mood'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: selectedMood == null,
                onSelected: (selected) {
                  setState(() => selectedMood = null);
                },
              ),
              ...moods.map((mood) => FilterChip(
                    label: Text(mood),
                    selected: selectedMood == mood,
                    onSelected: (selected) {
                      setState(() => selectedMood = selected ? mood : null);
                    },
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedMoodFilter = selectedMood;
                  _applyFilters();
                });
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditEntryDialog(JournalEntryModel entry) async {
    final contentController = TextEditingController(text: entry.content);
    String selectedMood = entry.mood;
    DateTime selectedDate = entry.date;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(entry.date);
    final moods = ['happy', 'sad', 'anxious', 'stressed', 'angry', 'neutral', 'depressed', 'overwhelmed'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Journal Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and Time Selection
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.pink[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Colors.pink[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Date & Time',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.pink[900],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: Colors.pink[600]!,
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: Colors.black87,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (pickedDate != null) {
                                  setState(() {
                                    selectedDate = pickedDate;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.pink[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.event, size: 18, color: Colors.pink[600]),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(selectedDate),
                                      style: TextStyle(color: Colors.pink[900]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: Colors.pink[600]!,
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: Colors.black87,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (pickedTime != null) {
                                  setState(() {
                                    selectedTime = pickedTime;
                                    selectedDate = DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                      selectedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.pink[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time, size: 18, color: Colors.pink[600]),
                                    const SizedBox(width: 8),
                                    Text(
                                      selectedTime.format(context),
                                      style: TextStyle(color: Colors.pink[900]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('How are you feeling?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: moods.map((mood) {
                    final isSelected = selectedMood == mood;
                    return FilterChip(
                      label: Text(mood),
                      selected: isSelected,
                      selectedColor: Colors.pink[100],
                      checkmarkColor: Colors.pink[700],
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.pink[900] : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                      onSelected: (selected) {
                        setState(() => selectedMood = mood);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    labelText: 'Write your thoughts...',
                    labelStyle: TextStyle(color: Colors.pink[700]),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.pink[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.pink[600]!, width: 2),
                    ),
                  ),
                  maxLines: 8,
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.pink[700])),
            ),
            ElevatedButton(
              onPressed: () async {
                if (contentController.text.trim().isNotEmpty) {
                  await _updateEntry(
                    entry,
                    contentController.text.trim(),
                    selectedMood,
                    selectedDate,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateEntry(JournalEntryModel entry, String content, String mood, DateTime? customDate) async {
    if (_currentUserId == null) return;

    try {
      final aiService = Provider.of<AIService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);

      final emotionAnalysis = await aiService.analyzeEmotions(
        content,
        _currentUserId!,
        null,
      );

      final moodScore = emotionAnalysis.overallScore;

      final updatedEntry = JournalEntryModel(
        id: entry.id,
        userId: entry.userId,
        content: content,
        mood: mood,
        moodScore: moodScore,
        date: customDate ?? entry.date,
        tags: entry.tags,
        emotionAnalysis: emotionAnalysis.emotionScores,
        stressTriggers: emotionAnalysis.suggestedActions,
      );

      final authService = Provider.of<AuthService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final currentUser = authService.currentUser;
      if (currentUser == null) return;

      final username = currentUser.name.toLowerCase().replaceAll(' ', '_');

      await dbService.writeData(
        '$userNodePath/$username/journal_entries/${entry.id}',
        updatedEntry.toMap(),
      );

      _loadEntries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal entry updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating entry: $e')),
        );
      }
    }
  }

  Future<void> _deleteEntry(JournalEntryModel entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this journal entry? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || _currentUserId == null) return;

    try {
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final currentUser = authService.currentUser;
      if (currentUser == null) return;

      final username = currentUser.name.toLowerCase().replaceAll(' ', '_');

      await dbService.deleteData('$userNodePath/$username/journal_entries/${entry.id}');

      _loadEntries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal entry deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting entry: $e')),
        );
      }
    }
  }

  Widget _buildGroupedEntriesSliver() {
    // Group entries by date
    final Map<String, List<JournalEntryModel>> entriesByDate = {};
    for (var entry in _filteredEntries) {
      final dateKey = DateFormat('yyyy-MM-dd').format(entry.date);
      entriesByDate.putIfAbsent(dateKey, () => []).add(entry);
    }

    // Sort dates (newest first)
    final sortedDates = entriesByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final dateKey = sortedDates[index];
          final date = DateTime.parse(dateKey);
          final entriesForDate = entriesByDate[dateKey]!;
          
          // Sort entries by time (newest first)
          entriesForDate.sort((a, b) => b.date.compareTo(a.date));

          return _buildDateGroup(date, entriesForDate);
        },
        childCount: sortedDates.length,
      ),
    );
  }

  Widget _buildDateGroup(DateTime date, List<JournalEntryModel> entries) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isToday = isSameDay(date, DateTime.now());
    final isYesterday = isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));
    
    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (isYesterday) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = dateFormat.format(date);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.pink[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.calendar_today,
            color: Colors.pink[700],
            size: 20,
          ),
        ),
        title: Text(
          dateLabel,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.pink[900],
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
          style: TextStyle(
            color: Colors.pink[600],
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.expand_more,
          color: Colors.pink[700],
        ),
        backgroundColor: Colors.pink[50],
        collapsedBackgroundColor: Colors.pink[50],
        children: entries.asMap().entries.map((entryMap) {
          final entryIndex = entryMap.key;
          final entry = entryMap.value;
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: entryIndex == entries.length - 1 ? 0 : 8,
            ),
            child: _JournalEntryCard(
              entry: entry,
              index: entryIndex,
              onEdit: () => _showEditEntryDialog(entry),
              onDelete: () => _deleteEntry(entry),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

class _JournalEntryCard extends StatefulWidget {
  final JournalEntryModel entry;
  final int index;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _JournalEntryCard({
    required this.entry,
    required this.index,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_JournalEntryCard> createState() => _JournalEntryCardState();
}

class _JournalEntryCardState extends State<_JournalEntryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600 + (widget.index * 100)),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.4, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Start animation immediately with a slight delay for staggered effect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(Duration(milliseconds: widget.index * 120), () {
          if (mounted) {
            _animationController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      }
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  String _getTimeOfDay(DateTime date) {
    final hour = date.hour;
    if (hour < 6) return 'Early Morning';
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    if (hour < 21) return 'Evening';
    return 'Night';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final moodColors = {
      'happy': Colors.pink[300]!,
      'sad': Colors.pink[400]!,
      'anxious': Colors.pink[500]!,
      'stressed': Colors.pink[600]!,
      'angry': Colors.pink[700]!,
      'neutral': Colors.pink[200]!,
      'depressed': Colors.pink[800]!,
      'overwhelmed': Colors.pink[900]!,
    };

    final moodIcons = {
      'happy': Icons.sentiment_very_satisfied,
      'sad': Icons.sentiment_dissatisfied,
      'anxious': Icons.sentiment_very_dissatisfied,
      'stressed': Icons.sentiment_dissatisfied,
      'angry': Icons.sentiment_very_dissatisfied,
      'neutral': Icons.sentiment_neutral,
      'depressed': Icons.sentiment_dissatisfied,
      'overwhelmed': Icons.sentiment_dissatisfied,
    };

    final moodColor = moodColors[widget.entry.mood] ?? Colors.grey;
    final moodIcon = moodIcons[widget.entry.mood] ?? Icons.sentiment_neutral;
    final relativeTime = _getRelativeTime(widget.entry.date);
    final timeOfDay = _getTimeOfDay(widget.entry.date);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  moodColor.withOpacity(0.3),
                  Colors.pink[50]!,
                ],
              ),
              border: Border(
                left: BorderSide(
                  color: moodColor,
                  width: 4,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with Mood, Date/Time, and Actions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mood Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: moodColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          moodIcon,
                          color: moodColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Mood Info and Date/Time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: moodColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.entry.mood.toUpperCase(),
                                        style: TextStyle(
                                          color: moodColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: moodColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${(widget.entry.moodScore * 100).toInt()}%',
                                        style: TextStyle(
                                          color: moodColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Date and Time Information
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  relativeTime,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeFormat.format(widget.entry.date),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${dateFormat.format(widget.entry.date)} • $timeOfDay',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Actions Menu
                      if (widget.onEdit != null || widget.onDelete != null)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onSelected: (value) {
                            if (value == 'edit' && widget.onEdit != null) {
                              widget.onEdit!();
                            } else if (value == 'delete' && widget.onDelete != null) {
                              widget.onDelete!();
                            }
                          },
                          itemBuilder: (context) => [
                            if (widget.onEdit != null)
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    const Text('Edit'),
                                  ],
                                ),
                              ),
                            if (widget.onDelete != null)
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 18, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Content
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.pink[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.pink[100]!),
                    ),
                    child: Text(
                      widget.entry.content,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  // Stress Triggers
                  if (widget.entry.stressTriggers != null &&
                      widget.entry.stressTriggers!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        ...widget.entry.stressTriggers!.take(3).map((trigger) {
                          return Chip(
                            label: Text(
                              trigger,
                              style: const TextStyle(fontSize: 11),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            backgroundColor: Colors.pink[100],
                            labelStyle: TextStyle(color: Colors.pink[900]),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

