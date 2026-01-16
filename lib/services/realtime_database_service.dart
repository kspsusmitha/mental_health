import 'package:firebase_database/firebase_database.dart';

class RealtimeDatabaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Generic write operation
  Future<void> writeData(String path, Map<String, dynamic> data) async {
    try {
      await _database.child(path).set(data);
    } catch (e) {
      throw Exception('Failed to write data: $e');
    }
  }

  // Generic update operation
  Future<void> updateData(String path, Map<String, dynamic> data) async {
    try {
      await _database.child(path).update(data);
    } catch (e) {
      throw Exception('Failed to update data: $e');
    }
  }

  // Generic read operation
  Future<Map<String, dynamic>?> readData(String path) async {
    try {
      final snapshot = await _database.child(path).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to read data: $e');
    }
  }

  // Generic delete operation
  Future<void> deleteData(String path) async {
    try {
      await _database.child(path).remove();
    } catch (e) {
      throw Exception('Failed to delete data: $e');
    }
  }

  // Get list of data from a path
  Future<List<Map<String, dynamic>>> readList(String path) async {
    try {
      final snapshot = await _database.child(path).get();
      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map) {
          return data.entries.map((entry) {
            final value = entry.value;
            if (value is Map) {
              final map = Map<String, dynamic>.from(value);
              // Ensure id field is set from the key if not present
              if (!map.containsKey('id') || map['id'] == null || map['id'] == '') {
                map['id'] = entry.key;
              }
              return map;
            }
            return <String, dynamic>{'id': entry.key};
          }).toList();
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to read list: $e');
    }
  }

  // Stream for real-time updates
  Stream<DatabaseEvent> streamData(String path) {
    return _database.child(path).onValue;
  }

  // Stream for list updates
  Stream<List<Map<String, dynamic>>> streamList(String path) {
    return _database.child(path).onValue.map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value;
        if (data is Map) {
          return data.entries.map((entry) {
            final value = entry.value as Map;
            return Map<String, dynamic>.from(value);
          }).toList();
        }
      }
      return [];
    });
  }

  // Query with ordering
  Future<List<Map<String, dynamic>>> queryOrdered(
    String path,
    String orderBy,
    {
    int? limitToFirst,
    int? limitToLast,
    dynamic startAt,
    dynamic endAt,
  }) async {
    try {
      Query query = _database.child(path).orderByChild(orderBy);
      
      if (startAt != null) query = query.startAt(startAt);
      if (endAt != null) query = query.endAt(endAt);
      if (limitToFirst != null) query = query.limitToFirst(limitToFirst);
      if (limitToLast != null) query = query.limitToLast(limitToLast);

      final snapshot = await query.get();
      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map) {
          return data.entries.map((entry) {
            final value = entry.value as Map;
            return Map<String, dynamic>.from(value);
          }).toList();
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to query data: $e');
    }
  }

  // Check if path exists
  Future<bool> exists(String path) async {
    try {
      final snapshot = await _database.child(path).get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // Push data (auto-generate key)
  Future<String> pushData(String path, Map<String, dynamic> data) async {
    try {
      final ref = _database.child(path).push();
      await ref.set(data);
      return ref.key ?? '';
    } catch (e) {
      throw Exception('Failed to push data: $e');
    }
  }
}

