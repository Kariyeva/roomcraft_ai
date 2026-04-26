import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedWork {
  final String imagePath;
  final String style;
  final String mode;
  final String dateLabel;
  final String prompt;
  final String description;
  final String userId;
  final List<Map<String, dynamic>> placedItems;

  const SavedWork({
    required this.imagePath,
    required this.style,
    required this.mode,
    required this.dateLabel,
    this.prompt = '',
    this.description = '',
    this.userId = '',
    this.placedItems = const [],
  });

  Map<String, dynamic> toMap({required String currentUserId}) {
    return {
      'imagePath': imagePath,
      'style': style,
      'mode': mode,
      'dateLabel': dateLabel,
      'prompt': prompt,
      'description': description,
      'userId': currentUserId,
      'placedItems': placedItems,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory SavedWork.fromMap(Map<String, dynamic> map) {
    return SavedWork(
      imagePath: map['imagePath'] ?? '',
      style: map['style'] ?? '',
      mode: map['mode'] ?? '',
      dateLabel: map['dateLabel'] ?? '',
      prompt: map['prompt'] ?? '',
      description: map['description'] ?? '',
      userId: map['userId'] ?? '',
      placedItems:
          (map['placedItems'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class SavedWorkWithId {
  final String id;
  final SavedWork work;

  const SavedWorkWithId({required this.id, required this.work});
}

class SavedWorksService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get _user => _auth.currentUser;

  static bool get isRegisteredUser {
    final user = _user;

    if (user == null) return false;
    if (user.isAnonymous) return false;

    return true;
  }

  static String? get _uid {
    if (!isRegisteredUser) return null;
    return _user?.uid;
  }

  static CollectionReference<Map<String, dynamic>>? get _worksRef {
    final uid = _uid;
    if (uid == null) return null;

    return _firestore.collection('users').doc(uid).collection('savedWorks');
  }

  static Future<List<SavedWork>> getWorks() async {
    final ref = _worksRef;
    if (ref == null) return [];

    final snapshot = await ref.orderBy('createdAt', descending: true).get();

    return snapshot.docs.map((doc) {
      return SavedWork.fromMap(doc.data());
    }).toList();
  }

  static Future<List<SavedWorkWithId>> getWorksWithIds() async {
    final ref = _worksRef;
    if (ref == null) return [];

    final snapshot = await ref.orderBy('createdAt', descending: true).get();

    return snapshot.docs.map((doc) {
      return SavedWorkWithId(id: doc.id, work: SavedWork.fromMap(doc.data()));
    }).toList();
  }

  static Stream<List<SavedWorkWithId>> getWorksStream() {
    final ref = _worksRef;

    if (ref == null) {
      return Stream.value([]);
    }

    return ref.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        return SavedWorkWithId(id: doc.id, work: SavedWork.fromMap(doc.data()));
      }).toList();
    });
  }

  static Future<void> saveWork(SavedWork work) async {
    final ref = _worksRef;
    final uid = _uid;

    if (ref == null || uid == null) return;

    await ref.add(work.toMap(currentUserId: uid));
  }

  static Future<void> deleteWork(String workId) async {
    final ref = _worksRef;
    if (ref == null) return;

    await ref.doc(workId).delete();
  }

  static Future<void> deleteWorkAt(int index) async {
    final ref = _worksRef;
    if (ref == null) return;

    final snapshot = await ref.orderBy('createdAt', descending: true).get();

    if (index >= 0 && index < snapshot.docs.length) {
      await snapshot.docs[index].reference.delete();
    }
  }
}
