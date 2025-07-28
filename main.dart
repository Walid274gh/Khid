import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'dart:math' show Point;
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:geocoding/geocoding.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;


// ===== VARIABLES GLOBALES =====

// Firebase instances
final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final FirebaseStorage _storage = FirebaseStorage.instance;
final FirebaseMessaging _messaging = FirebaseMessaging.instance;

// Background & Notifications
final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
final Workmanager _workManager = Workmanager();

// Couleurs du thème
const Color kPrimaryColor = Color(0xFF87CEEB);
const Color kSecondaryColor = Color(0xFFFFFFFF);
const Color kAccentColor = Color(0xFFFF8C00);
const Color kErrorColor = Color(0xFFE74C3C);
const Color kSuccessColor = Color(0xFF27AE60);

// Services disponibles
const List<String> kServices = [
  'Plomberie', 'Électricité', 'Nettoyage', 'Livraison', 'Peinture',
  'Réparation électroménager', 'Maçonnerie',
  'Climatisation',
  'Baby-sitting', 'Cours particuliers',
];

// Clés SharedPreferences
const String kUserTokenKey = 'user_token';
const String kWorkerStatusKey = 'worker_status';
const String kLocationPermissionKey = 'location_permission';

// ===== FONCTION MAIN =====
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final location = tz.getLocation('Africa/Algiers');
  tz.setLocalLocation(location);
  
  // Initialisation Firebase
  await Firebase.initializeApp();

  
  
  // Configuration des notifications locales
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  
  await _localNotifications.initialize(initializationSettings);
  
  // Configuration des permissions
  await _requestPermissions();
  
  // Initialisation du WorkManager pour les tâches en arrière-plan
  await _workManager.initialize(callbackDispatcher, isInDebugMode: false);
  
  // Configuration des notifications Firebase
  await _setupFirebaseMessaging();
  
  runApp(KhidmetiApp());
}

// Callback pour les tâches en arrière-plan
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Logique pour les tâches en arrière-plan (géolocalisation, notifications)
    print("Tâche en arrière-plan exécutée: $task");
    return Future.value(true);
  });
}

// Configuration des permissions
Future<void> _requestPermissions() async {
  await [
    Permission.camera,
    Permission.location,
    Permission.storage,
    Permission.phone,
    Permission.notification,
  ].request();
}

// Configuration Firebase Messaging
Future<void> _setupFirebaseMessaging() async {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  await _messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
}

// Handler pour les messages en arrière-plan
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Message reçu en arrière-plan: ${message.messageId}");
}

// ===== MODELS =====

class UserModel {
  final String uid;
  final String email;
  final String? phoneNumber;
  final String? facebookId;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isActive;
  final Map<String, dynamic>? preferences;
  final String avatarUrl;

  UserModel({
    required this.uid,
    required this.email,
    this.phoneNumber,
    this.facebookId,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    required this.createdAt,
    required this.lastLoginAt,
    this.isActive = true,
    this.preferences,
    required this.avatarUrl,
  });

  // Conversion vers Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'facebookId': facebookId,
      'firstName': firstName,
      'lastName': lastName,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'isActive': isActive,
      'preferences': preferences ?? {},
      'avatarUrl': avatarUrl,
    };
  }

  // Création depuis Map Firestore
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'],
      facebookId: map['facebookId'],
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
      preferences: map['preferences'],
      avatarUrl: map['avatarUrl'] ?? '',
    );
  }

  // Copie avec modifications
  UserModel copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? facebookId,
    String? firstName,
    String? lastName,
    String? profileImageUrl,
    DateTime? lastLoginAt,
    bool? isActive,
    Map<String, dynamic>? preferences,
    String? avatarUrl,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      facebookId: facebookId ?? this.facebookId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      preferences: preferences ?? this.preferences,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class WorkerModel {
  final String uid;
  final String cardNumber; // Numéro carte d'identité biométrique
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String email;
  final List<String> services; // Services proposés
  final String? profileImageUrl;
  final String? faceImageUrl; // Photo pour reconnaissance faciale
  final LatLng? currentLocation;
  final double rating;
  final int totalRatings;
  final bool isOnline;
  final bool isSubscribed;
  final DateTime? subscriptionEndDate;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final String? bio;
  final Map<String, double>? priceList; // Tarifs par service
  final List<String>? workingHours; // Heures de travail
  final bool isVerified;
  final String idType; // 'cni', 'permis', 'passeport'
  final String idPhotoUrl; // Photo de la pièce d'identité
  final String faceVerificationUrl; // Photo prise pour la vérification faciale
  final String avatarUrl;

  WorkerModel({
    required this.uid,
    required this.cardNumber,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.email,
    required this.services,
    this.profileImageUrl,
    this.faceImageUrl,
    this.currentLocation,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.isOnline = false,
    this.isSubscribed = false,
    this.subscriptionEndDate,
    required this.createdAt,
    required this.lastActiveAt,
    this.bio,
    this.priceList,
    this.workingHours,
    this.isVerified = false,
    required this.idType,
    required this.idPhotoUrl,
    required this.faceVerificationUrl,
    required this.avatarUrl,
  });

  // Conversion vers Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'cardNumber': cardNumber,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'email': email,
      'services': services,
      'profileImageUrl': profileImageUrl,
      'faceImageUrl': faceImageUrl,
      'currentLocation': currentLocation != null 
          ? {'lat': currentLocation!.latitude, 'lng': currentLocation!.longitude}
          : null,
      'rating': rating,
      'totalRatings': totalRatings,
      'isOnline': isOnline,
      'isSubscribed': isSubscribed,
      'subscriptionEndDate': subscriptionEndDate != null 
          ? Timestamp.fromDate(subscriptionEndDate!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      'bio': bio,
      'priceList': priceList ?? {},
      'workingHours': workingHours ?? [],
      'isVerified': isVerified,
      'idType': idType,
      'idPhotoUrl': idPhotoUrl,
      'faceVerificationUrl': faceVerificationUrl,
      'avatarUrl': avatarUrl,
    };
  }

  // Création depuis Map Firestore
  factory WorkerModel.fromMap(Map<String, dynamic> map) {
    LatLng? location;
    if (map['currentLocation'] != null) {
      final locMap = map['currentLocation'] as Map<String, dynamic>;
      location = LatLng(locMap['lat'].toDouble(), locMap['lng'].toDouble());
    }

    return WorkerModel(
      uid: map['uid'] ?? '',
      cardNumber: map['cardNumber'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'] ?? '',
      services: List<String>.from(map['services'] ?? []),
      profileImageUrl: map['profileImageUrl'],
      faceImageUrl: map['faceImageUrl'],
      currentLocation: location,
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
      isOnline: map['isOnline'] ?? false,
      isSubscribed: map['isSubscribed'] ?? false,
      subscriptionEndDate: map['subscriptionEndDate'] != null
          ? (map['subscriptionEndDate'] as Timestamp).toDate()
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastActiveAt: (map['lastActiveAt'] as Timestamp).toDate(),
      bio: map['bio'],
      priceList: Map<String, double>.from(map['priceList'] ?? {}),
      workingHours: List<String>.from(map['workingHours'] ?? []),
      isVerified: map['isVerified'] ?? false,
      idType: map['idType'] ?? '',
      idPhotoUrl: map['idPhotoUrl'] ?? '',
      faceVerificationUrl: map['faceVerificationUrl'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
    );
  }
  
  // Add after line 413
  WorkerModel copyWith({
  String? uid,
  String? cardNumber,
  String? firstName,
  String? lastName,
  String? phoneNumber,
  String? email,
  List<String>? services,
  String? profileImageUrl,
  String? faceImageUrl,
  LatLng? currentLocation,
  double? rating,
  int? totalRatings,
  bool? isOnline,
  bool? isSubscribed,
  DateTime? subscriptionEndDate,
  DateTime? createdAt,
  DateTime? lastActiveAt,
  String? bio,
  Map<String, double>? priceList,
  List<String>? workingHours,
  bool? isVerified,
  String? idType,
  String? idPhotoUrl,
  String? faceVerificationUrl,
  String? avatarUrl,
}) {
  return WorkerModel(
    uid: uid ?? this.uid,
    cardNumber: cardNumber ?? this.cardNumber,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    email: email ?? this.email,
    services: services ?? this.services,
    profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    faceImageUrl: faceImageUrl ?? this.faceImageUrl,
    currentLocation: currentLocation ?? this.currentLocation,
    rating: rating ?? this.rating,
    totalRatings: totalRatings ?? this.totalRatings,
    isOnline: isOnline ?? this.isOnline,
    isSubscribed: isSubscribed ?? this.isSubscribed,
    subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
    createdAt: createdAt ?? this.createdAt,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    bio: bio ?? this.bio,
    priceList: priceList ?? this.priceList,
    workingHours: workingHours ?? this.workingHours,
    isVerified: isVerified ?? this.isVerified,
    idType: idType ?? this.idType,
    idPhotoUrl: idPhotoUrl ?? this.idPhotoUrl,
    faceVerificationUrl: faceVerificationUrl ?? this.faceVerificationUrl,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );
}
  
}

class ServiceModel {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final Color color;
  final bool isActive;
  final int orderIndex;

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.color,
    this.isActive = true,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'color': color.value,
      'isActive': isActive,
      'orderIndex': orderIndex,
    };
  }

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    return ServiceModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      iconUrl: map['iconUrl'] ?? '',
      color: Color(map['color'] ?? 0xFF87CEEB),
      isActive: map['isActive'] ?? true,
      orderIndex: map['orderIndex'] ?? 0,
    );
  }
}

class RequestModel {
  final String id;
  final String userId;
  final String? workerId;
  final String serviceType;
  final String title;
  final String description;
  final LatLng location;
  final String address;
  final List<String> mediaUrls; // Photos/vidéos
  final double? budget;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? scheduledDate;
  final DateTime? completedAt;
  final double? rating;
  final String? review;
  final bool isUrgent;

  RequestModel({
    required this.id,
    required this.userId,
    this.workerId,
    required this.serviceType,
    required this.title,
    required this.description,
    required this.location,
    required this.address,
    this.mediaUrls = const [],
    this.budget,
    this.status = RequestStatus.pending,
    required this.createdAt,
    this.scheduledDate,
    this.completedAt,
    this.rating,
    this.review,
    this.isUrgent = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'workerId': workerId,
      'serviceType': serviceType,
      'title': title,
      'description': description,
      'location': {'lat': location.latitude, 'lng': location.longitude},
      'address': address,
      'mediaUrls': mediaUrls,
      'budget': budget,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledDate': scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'rating': rating,
      'review': review,
      'isUrgent': isUrgent,
    };
  }

  factory RequestModel.fromMap(Map<String, dynamic> map) {
    final locMap = map['location'] as Map<String, dynamic>;
    
    return RequestModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      workerId: map['workerId'],
      serviceType: map['serviceType'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: LatLng(locMap['lat'].toDouble(), locMap['lng'].toDouble()),
      address: map['address'] ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      budget: map['budget']?.toDouble(),
      status: RequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => RequestStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      scheduledDate: map['scheduledDate'] != null 
          ? (map['scheduledDate'] as Timestamp).toDate() 
          : null,
      completedAt: map['completedAt'] != null 
          ? (map['completedAt'] as Timestamp).toDate() 
          : null,
      rating: map['rating']?.toDouble(),
      review: map['review'],
      isUrgent: map['isUrgent'] ?? false,
    );
  }
}

enum RequestStatus {
  pending,
  accepted,
  inProgress,
  completed,
  cancelled,
  disputed
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String message;
  final MessageType type;
  final String? mediaUrl;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.type = MessageType.text,
    this.mediaUrl,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'type': type.toString().split('.').last,
      'mediaUrl': mediaUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      message: map['message'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['mediaUrl'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? message,
    MessageType? type,
    String? mediaUrl,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

enum MessageType {
  text,
  image,
  video,
  location,
  file
}
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Authentification utilisateur avec email
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Mettre à jour lastLoginAt
      if (credential.user != null) {
        await DatabaseService().updateUserLastLogin(credential.user!.uid);
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      print('Erreur de connexion: ${e.message}');
      return null;
    }
  }

  // Inscription utilisateur
  Future<UserCredential?> signUpWithEmail(String email, String password, String firstName, String lastName, String? phoneNumber) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Créer le profil utilisateur
        final user = UserModel(
          uid: credential.user!.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        
        await DatabaseService().createUser(user);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      print('Erreur d\'inscription: ${e.message}');
      return null;
    }
  }

  // Authentification travailleur avec carte d'identité
  Future<bool> authenticateWorker(String cardNumber, Uint8List faceImageData) async {
    try {
      // Vérifier si le travailleur existe
      final workerDoc = await _firestore
          .collection('workers')
          .where('cardNumber', isEqualTo: cardNumber)
          .get();

      if (workerDoc.docs.isEmpty) {
        return false;
      }

      final worker = WorkerModel.fromMap(workerDoc.docs.first.data());
      
      // Simuler la reconnaissance faciale (à remplacer par un service réel)
      bool faceRecognitionResult = await _performFaceRecognition(faceImageData, worker.faceImageUrl);
      
      if (faceRecognitionResult) {
        // Connexion réussie, mettre à jour les informations
        await DatabaseService().updateWorkerStatus(worker.uid, isOnline: true, lastActiveAt: DateTime.now());
        
        // Sauvegarder le token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kUserTokenKey, worker.uid);
        await prefs.setBool(kWorkerStatusKey, true);
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Erreur authentification travailleur: $e');
      return false;
    }
  }

  // Reconnaissance faciale réelle avec Google ML Kit
  Future<bool> _performFaceRecognition(Uint8List capturedImage, String? storedImageUrl) async {
    if (storedImageUrl == null || storedImageUrl.isEmpty) return false;
    
    try {
      // 1. Télécharger l'image de référence stockée
      final http.Response response = await http.get(Uri.parse(storedImageUrl));
      if (response.statusCode != 200) return false;
      
      final Uint8List storedImageBytes = response.bodyBytes;
      
      // 2. Détection des visages avec Google ML Kit
      final InputImage capturedInputImage = InputImage.fromBytes(
        bytes: capturedImage,
        metadata: InputImageMetadata(
          size: Size(640, 480), // Ajuster selon la résolution caméra
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 640,
        ),
      );
      
      final InputImage storedInputImage = InputImage.fromBytes(
        bytes: storedImageBytes,
        metadata: InputImageMetadata(
          size: Size(640, 480),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 640,
        ),
      );
      
      final FaceDetector detector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableClassification: true,
        ),
      );
      
      // 3. Détecter les visages dans les deux images
      final List<Face> capturedFaces = await detector.processImage(capturedInputImage);
      final List<Face> storedFaces = await detector.processImage(storedInputImage);
      
      detector.close();
      
      if (capturedFaces.isEmpty || storedFaces.isEmpty) {
        return false;
      }
      
      // 4. Comparaison des caractéristiques faciales
      final Face capturedFace = capturedFaces.first;
      final Face storedFace = storedFaces.first;
      
      // Comparaison des landmarks (points caractéristiques)
      double similarity = _compareFaceLandmarks(capturedFace, storedFace);
      
      // Seuil de similarité (ajustable selon la précision souhaitée)
      const double SIMILARITY_THRESHOLD = 0.85;
      
      return similarity >= SIMILARITY_THRESHOLD;
      
    } catch (e) {
      print('Erreur reconnaissance faciale: $e');
      return false;
    }
  }
  
  // Comparaison des points caractéristiques du visage
  double _compareFaceLandmarks(Face face1, Face face2) {
    double totalScore = 0.0;
    int comparisonCount = 0;
    
    // Comparaison des contours du visage
    final contours1 = face1.contours;
    final contours2 = face2.contours;
    
    if (contours1.isNotEmpty && contours2.isNotEmpty) {
      // Comparer les contours principaux
      for (FaceContourType type in [
        FaceContourType.face,
        FaceContourType.leftEye,
        FaceContourType.rightEye,
        FaceContourType.upperLipTop,
        FaceContourType.lowerLipBottom,
      ]) {
        final contour1 = contours1[type];
        final contour2 = contours2[type];
        
        if (contour1 != null && contour2 != null) {
          double contourSimilarity = _compareContours(contour1.points, contour2.points);
          totalScore += contourSimilarity;
          comparisonCount++;
        }
      }
    }
    
    // Comparaison des landmarks (points spécifiques)
    final landmarks1 = face1.landmarks;
    final landmarks2 = face2.landmarks;
    
    for (FaceLandmarkType type in [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
    ]) {
      final landmark1 = landmarks1[type];
      final landmark2 = landmarks2[type];
      
      if (landmark1 != null && landmark2 != null) {
        double distance = _calculatePointDistance(landmark1.position, landmark2.position);
        // Convertir la distance en score de similarité (plus la distance est petite, plus le score est élevé)
        double landmarkScore = math.max(0.0, 1.0 - (distance / 100.0)); // Normalisation
        totalScore += landmarkScore;
        comparisonCount++;
      }
    }
    
    // Comparaison des angles du visage
    if (face1.headEulerAngleY != null && face2.headEulerAngleY != null) {
      double angleDiff = (face1.headEulerAngleY! - face2.headEulerAngleY!).abs();
      double angleScore = math.max(0.0, 1.0 - (angleDiff / 30.0)); // Tolérance de 30 degrés
      totalScore += angleScore;
      comparisonCount++;
    }
    
    return comparisonCount > 0 ? totalScore / comparisonCount : 0.0;
  }
  
  // Comparaison de contours de points
  double _compareContours(List<Point<int>> contour1, List<Point<int>> contour2) {
    if (contour1.length != contour2.length) {
      // Redimensionner au plus petit contour pour la comparaison
      int minLength = math.min(contour1.length, contour2.length);
      contour1 = contour1.take(minLength).toList();
      contour2 = contour2.take(minLength).toList();
    }
    
    double totalDistance = 0.0;
    for (int i = 0; i < contour1.length; i++) {
      double distance = _calculatePointDistance(contour1[i], contour2[i]);
      totalDistance += distance;
    }
    
    double averageDistance = totalDistance / contour1.length;
    // Convertir en score de similarité
    return math.max(0.0, 1.0 - (averageDistance / 50.0)); // Normalisation
  }
  
  // Calcul de distance entre deux points
  double _calculatePointDistance(Point<int> p1, Point<int> p2) {
    return math.sqrt(math.pow(p1.x - p2.x, 2) + math.pow(p1.y - p2.y, 2));
  }

  // Déconnexion
  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Si c'est un travailleur, le mettre hors ligne
      final prefs = await SharedPreferences.getInstance();
      final isWorker = prefs.getBool(kWorkerStatusKey) ?? false;
      
      if (isWorker) {
        await DatabaseService().updateWorkerStatus(user.uid, isOnline: false);
      }
      
      await prefs.clear();
    }
    
    await _auth.signOut();
  }

  // Utilisateur actuellement connecté
  User? get currentUser => _auth.currentUser;

  // Stream d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // === GESTION UTILISATEURS ===
  
  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> updateUserLastLogin(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'lastLoginAt': Timestamp.now(),
    });
  }

  // === GESTION TRAVAILLEURS ===
  
  Future<void> createWorker(WorkerModel worker) async {
    await _firestore.collection('workers').doc(worker.uid).set(worker.toMap());
  }

  Future<WorkerModel?> getWorker(String uid) async {
    final doc = await _firestore.collection('workers').doc(uid).get();
    if (doc.exists) {
      return WorkerModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> updateWorkerLocation(String uid, LatLng location) async {
    await _firestore.collection('workers').doc(uid).update({
      'currentLocation': {'lat': location.latitude, 'lng': location.longitude},
      'lastActiveAt': Timestamp.now(),
    });
  }

  Future<void> updateWorkerStatus(String uid, {bool? isOnline, DateTime? lastActiveAt}) async {
    Map<String, dynamic> updates = {};
    if (isOnline != null) updates['isOnline'] = isOnline;
    if (lastActiveAt != null) updates['lastActiveAt'] = Timestamp.fromDate(lastActiveAt);
    
    if (updates.isNotEmpty) {
      await _firestore.collection('workers').doc(uid).update(updates);
    }
  }

  // Récupérer les travailleurs proches
  Future<List<WorkerModel>> getNearbyWorkers(LatLng userLocation, String serviceType, double radiusKm) async {
    final query = await _firestore
        .collection('workers')
        .where('services', arrayContains: serviceType)
        .where('isOnline', isEqualTo: true)
        .where('isSubscribed', isEqualTo: true)
        .get();

    List<WorkerModel> nearbyWorkers = [];
    
    for (var doc in query.docs) {
      final worker = WorkerModel.fromMap(doc.data());
      if (worker.currentLocation != null) {
        double distance = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          worker.currentLocation!.latitude,
          worker.currentLocation!.longitude,
        ) / 1000; // Convertir en km
        
        if (distance <= radiusKm) {
          nearbyWorkers.add(worker);
        }
      }
    }
    
    // Trier par distance
    nearbyWorkers.sort((a, b) {
      double distanceA = Geolocator.distanceBetween(
        userLocation.latitude, userLocation.longitude,
        a.currentLocation!.latitude, a.currentLocation!.longitude,
      );
      double distanceB = Geolocator.distanceBetween(
        userLocation.latitude, userLocation.longitude,
        b.currentLocation!.latitude, b.currentLocation!.longitude,
      );
      return distanceA.compareTo(distanceB);
    });
    
    return nearbyWorkers;
  }

  // === GESTION DEMANDES ===
  
  Future<String> createRequest(RequestModel request) async {
    final docRef = await _firestore.collection('requests').add(request.toMap());
    await _firestore.collection('requests').doc(docRef.id).update({'id': docRef.id});
    return docRef.id;
  }

  Future<void> updateRequestStatus(String requestId, RequestStatus status, {String? workerId}) async {
    Map<String, dynamic> updates = {'status': status.toString().split('.').last};
    if (workerId != null) updates['workerId'] = workerId;
    if (status == RequestStatus.completed) updates['completedAt'] = Timestamp.now();
    
    await _firestore.collection('requests').doc(requestId).update(updates);
  }

  Stream<List<RequestModel>> getUserRequests(String userId) {
    return _firestore
        .collection('requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data()))
            .toList());
  }

  Stream<List<RequestModel>> getWorkerRequests(String workerId) {
    return _firestore
        .collection('requests')
        .where('workerId', isEqualTo: workerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data()))
            .toList());
  }

  // === GESTION CHAT ===
  
  Future<void> sendMessage(ChatMessage message) async {
    await _firestore
        .collection('chats')
        .doc(message.chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toMap());
  }

  Stream<List<ChatMessage>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data()))
            .toList());
  }

  // === GESTION ÉVALUATIONS ===
  
  Future<void> rateWorker(String workerId, double rating, String? review) async {
    final workerRef = _firestore.collection('workers').doc(workerId);
    
    await _firestore.runTransaction((transaction) async {
      final workerDoc = await transaction.get(workerRef);
      if (workerDoc.exists) {
        final data = workerDoc.data()!;
        final currentRating = (data['rating'] ?? 0.0).toDouble();
        final totalRatings = (data['totalRatings'] ?? 0) as int;
        
        final newTotalRatings = totalRatings + 1;
        final newRating = ((currentRating * totalRatings) + rating) / newTotalRatings;
        
        transaction.update(workerRef, {
          'rating': newRating,
          'totalRatings': newTotalRatings,
        });
      }
    });
  }
}

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Upload d'image de profil
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      final ref = _storage.ref().child('profiles').child('$userId.jpg');
      final uploadTask = await ref.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Erreur upload image profil: $e');
      return null;
    }
  }

  // Upload d'image pour reconnaissance faciale
  Future<String?> uploadFaceImage(String workerId, File imageFile) async {
    try {
      final ref = _storage.ref().child('faces').child('$workerId.jpg');
      final uploadTask = await ref.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Erreur upload image visage: $e');
      return null;
    }
  }

  // Upload de médias pour demandes
  Future<List<String>> uploadRequestMedia(String requestId, List<File> mediaFiles) async {
    List<String> urls = [];
    
    for (int i = 0; i < mediaFiles.length; i++) {
      try {
        final file = mediaFiles[i];
        final extension = file.path.split('.').last.toLowerCase();
        final ref = _storage.ref().child('requests').child(requestId).child('media_$i.$extension');
        
        final uploadTask = await ref.putFile(file);
        final url = await uploadTask.ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        print('Erreur upload média $i: $e');
      }
    }
    
    return urls;
  }

  // Upload d'image de chat
  Future<String?> uploadChatImage(String chatId, File imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('chats').child(chatId).child('$timestamp.jpg');
      final uploadTask = await ref.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Erreur upload image chat: $e');
      return null;
    }
  }

  // Supprimer un fichier
  Future<bool> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return true;
    } catch (e) {
      print('Erreur suppression fichier: $e');
      return false;
    }
  }
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Vérifier les permissions de localisation
  Future<bool> checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  // Obtenir la position actuelle
  Future<Position?> getCurrentPosition() async {
    try {
      if (!await checkLocationPermission()) {
        return null;
      }
      
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Erreur obtention position: $e');
      return null;
    }
  }

  // Stream de position pour suivi en temps réel
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Mise à jour tous les 10 mètres
      ),
    );
  }

  // Calculer la distance entre deux points
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Obtenir l'adresse à partir des coordonnées
  Future<String> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (e) {
      print('Erreur geocoding: $e');
    }
    
    return 'Adresse inconnue';
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Initialiser les notifications
  Future<void> initialize() async {
    // Configuration Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Demander permission pour notifications
    await _requestNotificationPermissions();
    
    // Configuration FCM
    await _setupFCM();
  }

  Future<void> _requestNotificationPermissions() async {
    final permission = await Permission.notification.request();
    if (permission.isDenied) {
      print('Permission notification refusée');
    }
  }

  Future<void> _setupFCM() async {
    // Token FCM
    String? token = await _messaging.getToken();
    print('FCM Token: $token');

    // Écouter les messages en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Écouter les messages when app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Message reçu en foreground: ${message.notification?.title}');
    showLocalNotification(
      message.notification?.title ?? 'Khidmeti',
      message.notification?.body ?? '',
      message.data,
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('App ouverte depuis notification: ${message.data}');
    // Navigation selon le type de notification
  }

  // Afficher notification locale
  Future<void> showLocalNotification(String title, String body, [Map<String, dynamic>? data]) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'khidmeti_channel',
      'Khidmeti Notifications',
      channelDescription: 'Notifications de l\'application Khidmeti',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      print('Notification cliquée: $data');
      // Navigation selon les données
    }
  }

  // Envoyer notification à un utilisateur spécifique
  Future<void> sendNotificationToUser(String userId, String title, String body, Map<String, String> data) async {
    // Ici, envoyer via FCM server-side
    // Pour la démo, on affiche juste localement
    await showLocalNotification(title, body, data);
  }
}
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  // Initialiser les services en arrière-plan
  Future<void> initialize() async {
    await _workManager.initialize(
      _callbackDispatcher,
      isInDebugMode: false,
    );
  }

  // Démarrer le suivi de localisation pour les travailleurs
  Future<void> startLocationTracking(String workerId) async {
    await _workManager.registerPeriodicTask(
      "location_tracking_$workerId",
      "updateWorkerLocation",
      frequency: Duration(minutes: 5),
      inputData: {'workerId': workerId},
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  // Arrêter le suivi de localisation
  Future<void> stopLocationTracking(String workerId) async {
    await _workManager.cancelByUniqueName("location_tracking_$workerId");
  }

  // Callback pour les tâches en arrière-plan
  static void _callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      switch (task) {
        case "updateWorkerLocation":
          await _updateWorkerLocationInBackground(inputData?['workerId']);
          break;
        default:
          print('Tâche inconnue: $task');
      }
      return Future.value(true);
    });
  }

  static Future<void> _updateWorkerLocationInBackground(String? workerId) async {
    if (workerId == null) return;
    
    try {
      // Initialiser Firebase si nécessaire
      await Firebase.initializeApp();
      
      // Obtenir la position actuelle
      final position = await LocationService().getCurrentPosition();
      if (position != null) {
        final location = LatLng(position.latitude, position.longitude);
        await DatabaseService().updateWorkerLocation(workerId, location);
        print('Position mise à jour en arrière-plan pour $workerId');
      }
    } catch (e) {
      print('Erreur mise à jour position en arrière-plan: $e');
    }
  }

  // Programmer une notification
  Future<void> scheduleNotification(String title, String body, DateTime scheduledTime) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'khidmeti_scheduled',
      'Notifications programmées',
      channelDescription: 'Notifications programmées de Khidmeti',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      timeoutAfter: 0,
      autoCancel: true,
      showWhen: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // ===== CORRECTION APPLIQUÉE ICI (LIGNE SUPPRIMÉE) =====
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}




//KHIDMETI APP - DÉVELOPPEMENT DE LA CLASSE : KhidmetiApp

// ===== CLASSE DÉVELOPPÉE DANS CETTE RÉPONSE =====

class KhidmetiApp extends StatelessWidget {
  const KhidmetiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Khidmeti',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Couleurs principales
        primaryColor: kPrimaryColor,
        primarySwatch: _createMaterialColor(kPrimaryColor),
        scaffoldBackgroundColor: kSecondaryColor,
        
        // Configuration de l'AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimaryColor,
          foregroundColor: kSecondaryColor,
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: kSecondaryColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
          iconTheme: IconThemeData(
            color: kSecondaryColor,
            size: 24,
          ),
        ),
        
        // Configuration des couleurs
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          primary: kPrimaryColor,
          secondary: kAccentColor,
          surface: kSecondaryColor,
          error: kErrorColor,
          brightness: Brightness.light,
        ),
        
        // Configuration des boutons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: kSecondaryColor,
            elevation: 3,
            shadowColor: kPrimaryColor.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        
        // Configuration des boutons texte
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kPrimaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        // Configuration des boutons outline
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kPrimaryColor,
            side: const BorderSide(color: kPrimaryColor, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        // Configuration des inputs
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kErrorColor, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kErrorColor, width: 2),
          ),
          labelStyle: const TextStyle(
            color: Colors.grey,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 15,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        
        // Configuration des cartes
        cardTheme: CardTheme(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: kSecondaryColor,
        ),
        
        // Configuration de la barre de navigation
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: kSecondaryColor,
          selectedItemColor: kPrimaryColor,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
        
        // Configuration des icônes
        iconTheme: const IconThemeData(
          color: kPrimaryColor,
          size: 24,
        ),
        
        // Configuration des textes
        textTheme: const TextTheme(
          // Titres principaux
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.3,
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          
          // Titres secondaires
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          titleSmall: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
          
          // Corps de texte
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
            height: 1.4,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.black54,
          ),
          
          // Étiquettes
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        
        // Configuration des dividers
        dividerTheme: DividerThemeData(
          color: Colors.grey[300],
          thickness: 1,
          space: 1,
        ),
        
        // Configuration des floating action buttons
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: kAccentColor,
          foregroundColor: kSecondaryColor,
          elevation: 6,
          shape: CircleBorder(),
        ),
        
        // Configuration des dialogues
        dialogTheme: DialogTheme(
          backgroundColor: kSecondaryColor,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        
        
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.black87,
          contentTextStyle: const TextStyle(
            color: kSecondaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          behavior: SnackBarBehavior.floating,
          insetPadding: const EdgeInsets.all(16),
        ),
        
        // Configuration des chips
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey[100]!,
          selectedColor: kPrimaryColor.withOpacity(0.2),
          disabledColor: Colors.grey[300]!,
          labelStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          secondaryLabelStyle: const TextStyle(
            color: kPrimaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        
        // Police par défaut
        fontFamily: 'Roboto',
        
        // Configuration des animations
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        
        // Usabilité
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      
      // Page d'accueil
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          // Écran de chargement pendant la vérification de l'authentification
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          
          // Si l'utilisateur est connecté, aller à l'écran principal
          if (snapshot.hasData) {
            return const MainNavigationScreen();
          }
          
          // Sinon, afficher l'écran d'authentification
          return const AuthScreen();
        },
      ),
      
      // Routes nommées pour la navigation
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const MainNavigationScreen(),
        '/worker-registration': (context) => const WorkerRegistrationScreen(),
        

      },
      
      // Page d'erreur si route non trouvée
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Page non trouvée'),
            ),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: kErrorColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Page non trouvée',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'La page que vous cherchez n\'existe pas.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Créer un MaterialColor à partir d'une Color
  MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    
    return MaterialColor(color.value, swatch);
  }
}

// Écran principal avec navigation par onglets
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  
  // Liste des écrans de navigation
  final List<Widget> _screens = [
    HomeScreen(),
    SearchScreen(),
    const RequestsScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: kSecondaryColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: kPrimaryColor,
              unselectedItemColor: Colors.grey[500],
              selectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Accueil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search_outlined),
                  activeIcon: Icon(Icons.search),
                  label: 'Recherche',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_outlined),
                  activeIcon: Icon(Icons.assignment),
                  label: 'Demandes',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: 'Messages',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== SPLASH SCREEN =====
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    ));

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Attendre que les animations commencent
      await Future.delayed(const Duration(milliseconds: 1000));

      // Initialiser les services
      await _initializeServices();

      // Vérifier l'authentification
      await _checkAuthentication();

    } catch (e) {
      print('Erreur initialisation: $e');
      _navigateToAuth();
    }
  }

  Future<void> _initializeServices() async {
    // Initialiser les notifications
    await NotificationService().initialize();
    
    // Initialiser les services en arrière-plan
    await BackgroundService().initialize();
    
    // Vérifier les permissions
    await _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Vérifier permission de localisation
    final locationPermission = await LocationService().checkLocationPermission();
    if (locationPermission) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kLocationPermissionKey, true);
    }
  }

  Future<void> _checkAuthentication() async {
    // Attendre la fin des animations
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    final userToken = prefs.getString(kUserTokenKey);
    final isWorker = prefs.getBool(kWorkerStatusKey) ?? false;

    if (userToken != null && userToken.isNotEmpty) {
      // Utilisateur déjà connecté
      if (isWorker) {
        // Travailleur connecté - aller au home travailleur
        _navigateToHome(isWorker: true);
      } else {
        // Client connecté - aller au home client
        _navigateToHome(isWorker: false);
      }
    } else {
      // Pas de connexion - aller à l'écran d'authentification
      _navigateToAuth();
    }
  }

  void _navigateToHome({required bool isWorker}) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            HomeScreen(isWorker: isWorker),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // Espace supérieur
            const Spacer(flex: 2),
            
            // Logo et titre animés
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animé
                  AnimatedBuilder(
                    animation: _logoAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: kSecondaryColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.handyman_rounded,
                            size: 60,
                            color: kPrimaryColor,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Titre animé
                  AnimatedBuilder(
                    animation: _textAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textAnimation.value,
                        child: Column(
                          children: [
                            Text(
                              'Khidmeti',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: kSecondaryColor,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Votre service à domicile',
                              style: TextStyle(
                                fontSize: 16,
                                color: kSecondaryColor.withOpacity(0.9),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Message de chargement animé
            Expanded(
              flex: 2,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Indicateur de chargement personnalisé
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(kSecondaryColor),
                        strokeWidth: 3,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Text(
                      'Initialisation...',
                      style: TextStyle(
                        fontSize: 14,
                        color: kSecondaryColor.withOpacity(0.8),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer avec version
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: kSecondaryColor.withOpacity(0.6),
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== AUTH SCREEN =====
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PageController _pageController = PageController();
  
  // Controllers pour les formulaires
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  // État du formulaire
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentIndex = 0; // 0: Connexion, 1: Inscription
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentIndex = _tabController.index;
      });
      _pageController.animateToPage(
        _tabController.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Connexion utilisateur
  Future<void> _signIn() async {
    if (!_validateSignInForm()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await AuthService().signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (credential != null) {
        // Sauvegarder les informations de connexion
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kUserTokenKey, credential.user!.uid);
        await prefs.setBool(kWorkerStatusKey, false);

        // Afficher message de succès
        _showSnackBar('Connexion réussie !', kSuccessColor);
        
        // Naviguer vers l'accueil
        _navigateToHome();
      } else {
        _showSnackBar('Email ou mot de passe incorrect', kErrorColor);
      }
    } catch (e) {
      _showSnackBar('Erreur de connexion', kErrorColor);
    }

    setState(() => _isLoading = false);
  }

  // Inscription utilisateur
  Future<void> _signUp() async {
    if (!_validateSignUpForm()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await AuthService().signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
        _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );

      if (credential != null) {
        // Sauvegarder les informations
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kUserTokenKey, credential.user!.uid);
        await prefs.setBool(kWorkerStatusKey, false);

        _showSnackBar('Inscription réussie !', kSuccessColor);
        _navigateToHome();
      } else {
        _showSnackBar('Erreur lors de l\'inscription', kErrorColor);
      }
    } catch (e) {
      _showSnackBar('Erreur d\'inscription', kErrorColor);
    }

    setState(() => _isLoading = false);
  }

  // Validation formulaire connexion
  bool _validateSignInForm() {
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Veuillez saisir votre email', kErrorColor);
      return false;
    }
    if (!_isValidEmail(_emailController.text.trim())) {
      _showSnackBar('Format d\'email invalide', kErrorColor);
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _showSnackBar('Veuillez saisir votre mot de passe', kErrorColor);
      return false;
    }
    return true;
  }

  // Validation formulaire inscription
  bool _validateSignUpForm() {
    if (_firstNameController.text.trim().isEmpty) {
      _showSnackBar('Veuillez saisir votre prénom', kErrorColor);
      return false;
    }
    if (_lastNameController.text.trim().isEmpty) {
      _showSnackBar('Veuillez saisir votre nom', kErrorColor);
      return false;
    }
    if (_emailController.text.trim().isEmpty || !_isValidEmail(_emailController.text.trim())) {
      _showSnackBar('Email invalide', kErrorColor);
      return false;
    }
    if (_passwordController.text.length < 6) {
      _showSnackBar('Le mot de passe doit contenir au moins 6 caractères', kErrorColor);
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Les mots de passe ne correspondent pas', kErrorColor);
      return false;
    }
    return true;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen(isWorker: false)),
    );
  }

  void _navigateToWorkerAuth() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const WorkerRegistrationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSecondaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header avec logo
            _buildHeader(),
            
            // Tabs
            _buildTabs(),
            
            // Contenu des formulaires
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  _tabController.animateTo(index);
                },
                children: [
                  _buildSignInForm(),
                  _buildSignUpForm(),
                ],
              ),
            ),
            
            // Footer avec option travailleur
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kPrimaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.handyman_rounded,
              size: 40,
              color: kSecondaryColor,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Khidmeti',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Votre service à domicile',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(25),
        ),
        labelColor: kSecondaryColor,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Connexion'),
          Tab(text: 'Inscription'),
        ],
      ),
    );
  }

  Widget _buildSignInForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          
          // Email
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          
          const SizedBox(height: 20),
          
          // Mot de passe
          _buildTextField(
            controller: _passwordController,
            label: 'Mot de passe',
            icon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          
          const SizedBox(height: 30),
          
          // Bouton connexion
          _buildActionButton(
            text: 'Se connecter',
            onPressed: _signIn,
          ),
          
          const SizedBox(height: 20),
          
          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'ou',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Bouton Facebook (simulé)
          _buildSocialButton(
            text: 'Continuer avec Facebook',
            icon: Icons.facebook,
            color: const Color(0xFF1877F2),
            onPressed: () => _showSnackBar('Facebook - Fonctionnalité en développement', Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          
          // Prénom
          _buildTextField(
            controller: _firstNameController,
            label: 'Prénom',
            icon: Icons.person_outline,
          ),
          
          const SizedBox(height: 15),
          
          // Nom
          _buildTextField(
            controller: _lastNameController,
            label: 'Nom',
            icon: Icons.person_outline,
          ),
          
          const SizedBox(height: 15),
          
          // Email
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          
          const SizedBox(height: 15),
          
          // Téléphone (optionnel)
          _buildTextField(
            controller: _phoneController,
            label: 'Téléphone (optionnel)',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          
          const SizedBox(height: 15),
          
          // Mot de passe
          _buildTextField(
            controller: _passwordController,
            label: 'Mot de passe',
            icon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          
          const SizedBox(height: 15),
          
          // Confirmer mot de passe
          _buildTextField(
            controller: _confirmPasswordController,
            label: 'Confirmer mot de passe',
            icon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscureConfirmPassword,
            onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          
          const SizedBox(height: 25),
          
          // Bouton inscription
          _buildActionButton(
            text: 'S\'inscrire',
            onPressed: _signUp,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kPrimaryColor),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[600],
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          labelStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }
  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: kSecondaryColor,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: kSecondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        icon: Icon(icon, color: kSecondaryColor),
        label: Text(
          text,
          style: const TextStyle(
            color: kSecondaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 15),
          
          Text(
            'Vous êtes un travailleur ?',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 10),
          
          TextButton(
            onPressed: _navigateToWorkerAuth,
            child: const Text(
              'Inscription Travailleur',
              style: TextStyle(
                color: kPrimaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ===== HOME SCREEN =====
class HomeScreen extends StatefulWidget {
  final bool? isWorker;
  
  const HomeScreen({Key? key, this.isWorker}) : super(key: key);
  

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> 
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  
  UserModel? _currentUser;
  WorkerModel? _currentWorker;
  bool _isLoading = true;
  Position? _currentPosition;
  List<WorkerModel> _nearbyWorkers = [];
  List<RequestModel> _recentRequests = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    
    _initializeHome();
  }

  Future<void> _initializeHome() async {
    await _loadUserData();
    await _getCurrentLocation();
    if (!(widget.isWorker ?? false)) {
      await _loadNearbyWorkers();
    }
    await _loadRecentRequests();
    
    setState(() => _isLoading = false);
    _fabAnimationController.forward();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(kUserTokenKey);
    
    if (userId != null) {
      if (!(widget.isWorker ?? false)) {
        _currentWorker = await DatabaseService().getWorker(userId);
        if (_currentWorker != null) {
          // Mettre à jour le statut en ligne du travailleur
          await DatabaseService().updateWorkerStatus(userId, isOnline: true);
          // Démarrer le suivi de localisation
          await BackgroundService().startLocationTracking(userId);
        }
      } else {
        _currentUser = await DatabaseService().getUser(userId);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    _currentPosition = await LocationService().getCurrentPosition();
    if (_currentPosition != null && (widget.isWorker ?? false) && _currentWorker != null) {
      // Mettre à jour la position du travailleur
      final location = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      await DatabaseService().updateWorkerLocation(_currentWorker!.uid, location);
    }
  }

  Future<void> _loadNearbyWorkers() async {
    if (_currentPosition != null) {
      final location = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      _nearbyWorkers = await DatabaseService().getNearbyWorkers(
        location, 
        kServices.first, // Service par défaut
        10.0, // Rayon de 10km
      );
    }
  }

  Future<void> _loadRecentRequests() async {
    if (widget.isWorker ?? false && _currentWorker != null) {
      // Pour les travailleurs : leurs demandes acceptées
      DatabaseService().getWorkerRequests(_currentWorker!.uid).listen((requests) {
        if (mounted) {
          setState(() {
            _recentRequests = requests.take(5).toList();
          });
        }
      });
    } else if (_currentUser != null) {
      // Pour les clients : leurs demandes
      DatabaseService().getUserRequests(_currentUser!.uid).listen((requests) {
        if (mounted) {
          setState(() {
            _recentRequests = requests.take(5).toList();
          });
        }
      });
    }
  }

  void _onBottomNavTap(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _refreshHome() async {
    setState(() => _isLoading = true);
    await _initializeHome();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kSecondaryColor,
        body: Center(
          child: CircularProgressIndicator(color: kPrimaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          _buildHomePage(),
          _buildSearchPage(),
          _buildRequestsPage(),
          _buildChatPage(),
          _buildProfilePage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _currentIndex == 0 ? _buildFloatingActionButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHomePage() {
    return RefreshIndicator(
      onRefresh: _refreshHome,
      color: kPrimaryColor,
      child: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!(widget.isWorker ?? false))...[
                  _buildQuickActions(),
                  _buildServicesGrid(),
                  _buildNearbyWorkers(),
                ] else ...[
                  _buildWorkerStats(),
                  _buildWorkerActions(),
                ],
                _buildRecentActivity(),
                const SizedBox(height: 100), // Espace pour le FAB
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final userName = widget.isWorker ?? false 
        ? '${_currentWorker?.firstName ?? ''} ${_currentWorker?.lastName ?? ''}'
        : '${_currentUser?.firstName ?? ''} ${_currentUser?.lastName ?? ''}';

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: kPrimaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.isWorker ?? false ? 'Tableau de bord' : 'Accueil',
          style: const TextStyle(
            color: kSecondaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kPrimaryColor,
                kPrimaryColor.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: kSecondaryColor,
                    backgroundImage: widget.isWorker ?? false 
                        ? (_currentWorker?.profileImageUrl != null 
                            ? CachedNetworkImageProvider(_currentWorker!.profileImageUrl!)
                            : null)
                        : (_currentUser?.profileImageUrl != null 
                            ? CachedNetworkImageProvider(_currentUser!.profileImageUrl!)
                            : null),
                    child: (widget.isWorker ?? false ? _currentWorker?.profileImageUrl : _currentUser?.profileImageUrl) == null
                        ? Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Bonjour,',
                          style: TextStyle(
                            color: kSecondaryColor.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          userName.isNotEmpty ? userName : 'Utilisateur',
                          style: const TextStyle(
                            color: kSecondaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Navigation vers notifications
                    },
                    icon: Stack(
                      children: [
                        const Icon(Icons.notifications_outlined, color: kSecondaryColor),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: kAccentColor,
                              shape: BoxShape.circle,
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
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions rapides',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.search,
                  title: 'Trouver',
                  subtitle: 'un service',
                  color: kPrimaryColor,
                  onTap: () => _onBottomNavTap(1),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.history,
                  title: 'Mes',
                  subtitle: 'demandes',
                  color: kAccentColor,
                  onTap: () => _onBottomNavTap(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services populaires',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            itemCount: kServices.take(6).length,
            itemBuilder: (context, index) {
              final service = kServices[index];
              return _buildServiceCard(service, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(String service, int index) {
    final colors = [
      kPrimaryColor,
      kAccentColor,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];
    
    final icons = [
      Icons.plumbing,
      Icons.electrical_services,
      Icons.cleaning_services,
      Icons.delivery_dining,
      Icons.format_paint,
      Icons.build,
    ];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceDetailScreen(serviceName: service, serviceType: service, userLocation: LatLng(_currentPosition!.latitude, _currentPosition!.longitude)),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: kSecondaryColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icons[index % icons.length],
              color: colors[index % colors.length],
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              service,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyWorkers() {
    if (_nearbyWorkers.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Travailleurs proches',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () => _onBottomNavTap(1),
                child: const Text(
                  'Voir tout',
                  style: TextStyle(color: kPrimaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _nearbyWorkers.take(5).length,
              itemBuilder: (context, index) {
                final worker = _nearbyWorkers[index];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 15),
                  child: WorkerCard(worker: worker),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerStats() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vos statistiques',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Note',
                  value: _currentWorker?.rating.toStringAsFixed(1) ?? '0.0',
                  icon: Icons.star,
                  color: kAccentColor,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  title: 'Services',
                  value: '${_recentRequests.length}',
                  icon: Icons.work,
                  color: kPrimaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSecondaryColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  title: _currentWorker?.isOnline == true ? 'En ligne' : 'Hors ligne',
                  icon: _currentWorker?.isOnline == true ? Icons.toggle_on : Icons.toggle_off,
                  color: _currentWorker?.isOnline == true ? kSuccessColor : Colors.grey,
                  onTap: _toggleWorkerStatus,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildActionButton(
                  title: 'Abonnement',
                  icon: Icons.card_membership,
                  color: kAccentColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SubscriptionScreen(worker: _currentWorker!)),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleWorkerStatus() async {
    if (_currentWorker != null) {
      final newStatus = !(_currentWorker!.isOnline);
      await DatabaseService().updateWorkerStatus(
        _currentWorker!.uid,
        isOnline: newStatus,
      );
      
      setState(() {
        _currentWorker = _currentWorker!.copyWith(isOnline: newStatus);
      });

      if (newStatus) {
        await BackgroundService().startLocationTracking(_currentWorker!.uid);
      } else {
        await BackgroundService().stopLocationTracking(_currentWorker!.uid);
      }
    }
  }

  Widget _buildRecentActivity() {
    if (_recentRequests.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isWorker ?? false ? 'Demandes récentes' : 'Mes demandes récentes',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentRequests.take(3).length,
            itemBuilder: (context, index) {
              final request = _recentRequests[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: RequestCard(request: request, isWorker: true, onComplete: () {}, onCancel: () {}, isHistory: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPage() {
    return const Center(
      child: Text(
        'Page de recherche',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildRequestsPage() {
    return const Center(
      child: Text(
        'Page des demandes',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildChatPage() {
    return const Center(
      child: Text(
        'Page de chat',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildProfilePage() {
    return const Center(
      child: Text(
        'Page de profil',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: kSecondaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: kPrimaryColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Recherche',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_outlined),
            activeIcon: Icon(Icons.list),
            label: 'Demandes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (widget.isWorker ?? false) return const SizedBox.shrink();

    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailScreen(serviceName: 'Nouveau service', serviceType: 'DefaultService', userLocation: LatLng(_currentPosition!.latitude, _currentPosition!.longitude)),
            ),
          );
        },
        backgroundColor: kAccentColor,
        foregroundColor: kSecondaryColor,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nouvelle demande',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    );
  }
}


// ===== WORKER REGISTRATION SCREEN =====
class WorkerRegistrationScreen extends StatefulWidget {
  const WorkerRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<WorkerRegistrationScreen> createState() => _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> 
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Controllers pour les formulaires
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // État du formulaire
  int _currentStep = 0;
  bool _isLoading = false;
  File? _profileImage;
  File? _faceImage;
  List<String> _selectedServices = [];
  Map<String, double> _priceList = {};
  List<String> _workingHours = [];
  bool _cameraPermissionGranted = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() => _cameraPermissionGranted = true);
    } else if (status.isDenied) {
      final result = await Permission.camera.request();
      setState(() => _cameraPermissionGranted = result.isGranted);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _cardNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _submitRegistration();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Informations personnelles
        if (_cardNumberController.text.trim().length != 18) {
          _showSnackBar('Le numéro de carte doit contenir 18 caractères', kErrorColor);
          return false;
        }
        if (_firstNameController.text.trim().isEmpty) {
          _showSnackBar('Veuillez saisir votre prénom', kErrorColor);
          return false;
        }
        if (_lastNameController.text.trim().isEmpty) {
          _showSnackBar('Veuillez saisir votre nom', kErrorColor);
          return false;
        }
        if (_phoneController.text.trim().isEmpty) {
          _showSnackBar('Veuillez saisir votre téléphone', kErrorColor);
          return false;
        }
        if (_emailController.text.trim().isEmpty || !_isValidEmail(_emailController.text.trim())) {
          _showSnackBar('Email invalide', kErrorColor);
          return false;
        }
        return true;

      case 1: // Services
        if (_selectedServices.isEmpty) {
          _showSnackBar('Veuillez sélectionner au moins un service', kErrorColor);
          return false;
        }
        return true;

      case 2: // Tarifs
        for (String service in _selectedServices) {
          if (_priceList[service] == null || _priceList[service]! <= 0) {
            _showSnackBar('Veuillez définir un tarif pour $service', kErrorColor);
            return false;
          }
        }
        return true;

      case 3: // Photos
        if (_profileImage == null) {
          _showSnackBar('Veuillez ajouter une photo de profil', kErrorColor);
          return false;
        }
        if (_faceImage == null) {
          _showSnackBar('Veuillez ajouter une photo pour la reconnaissance faciale', kErrorColor);
          return false;
        }
        return true;

      case 4: // Vérification
        return true;

      default:
        return true;
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() => _profileImage = File(image.path));
    }
  }

  Future<void> _takeFacePhoto() async {
    if (!_cameraPermissionGranted) {
      _showSnackBar('Permission caméra requise', kErrorColor);
      return;
    }

    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );

    if (image != null) {
      setState(() => _faceImage = File(image.path));
    }
  }

  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);

    try {
      // 1. Upload des images
      String? profileImageUrl;
      String? faceImageUrl;

      if (_profileImage != null) {
        profileImageUrl = await StorageService().uploadProfileImage(
          _cardNumberController.text,
          _profileImage!,
        );
      }

      if (_faceImage != null) {
        faceImageUrl = await StorageService().uploadFaceImage(
          _cardNumberController.text,
          _faceImage!,
        );
      }

      // 2. Créer le modèle travailleur
      final worker = WorkerModel(
        uid: _cardNumberController.text, // Utiliser le numéro de carte comme ID
        cardNumber: _cardNumberController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        services: _selectedServices,
        profileImageUrl: profileImageUrl,
        faceImageUrl: faceImageUrl,
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        priceList: _priceList,
        workingHours: _workingHours,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      // 3. Sauvegarder dans Firestore
      await DatabaseService().createWorker(worker);

      // 4. Sauvegarder les informations localement
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kUserTokenKey, worker.uid);
      await prefs.setBool(kWorkerStatusKey, true);

      _showSnackBar('Inscription réussie !', kSuccessColor);

      // 5. Naviguer vers l'accueil travailleur
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(isWorker: true),
        ),
        (route) => false,
      );

    } catch (e) {
      _showSnackBar('Erreur lors de l\'inscription', kErrorColor);
      print('Erreur inscription travailleur: $e');
    }

    setState(() => _isLoading = false);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSecondaryColor,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kSecondaryColor),
          onPressed: _currentStep > 0 ? _previousStep : () => Navigator.pop(context),
        ),
        title: const Text(
          'Inscription Travailleur',
          style: TextStyle(
            color: kSecondaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildProgressIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPersonalInfoStep(),
                    _buildServicesStep(),
                    _buildPricingStep(),
                    _buildPhotosStep(),
                    _buildVerificationStep(),
                  ],
                ),
              ),
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: List.generate(5, (index) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 4 ? 10 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentStep ? kPrimaryColor : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations personnelles',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Saisissez vos informations personnelles',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),

          _buildTextField(
            controller: _cardNumberController,
            label: 'Numéro carte d\'identité',
            icon: Icons.credit_card,
            maxLength: 18,
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _firstNameController,
                  label: 'Prénom',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildTextField(
                  controller: _lastNameController,
                  label: 'Nom',
                  icon: Icons.person_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _buildTextField(
            controller: _phoneController,
            label: 'Téléphone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 20),

          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 20),

          _buildTextField(
            controller: _bioController,
            label: 'Présentation (optionnel)',
            icon: Icons.info_outline,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildServicesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services proposés',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Sélectionnez les services que vous proposez',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: kServices.length,
            itemBuilder: (context, index) {
              final service = kServices[index];
              final isSelected = _selectedServices.contains(service);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedServices.remove(service);
                      _priceList.remove(service);
                    } else {
                      _selectedServices.add(service);
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryColor.withOpacity(0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? kPrimaryColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? kPrimaryColor : Colors.grey[400],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          service,
                          style: TextStyle(
                            color: isSelected ? kPrimaryColor : Colors.black87,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPricingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tarification',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Définissez vos tarifs par service (DA/heure)',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedServices.length,
            itemBuilder: (context, index) {
              final service = _selectedServices[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        service,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Prix DA',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (value) {
                          final price = double.tryParse(value);
                          if (price != null) {
                            _priceList[service] = price;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  Widget _buildPhotosStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ajoutez vos photos pour la vérification',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),

          // Photo de profil
          const Text(
            'Photo de profil',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: _pickProfileImage,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
              ),
              child: _profileImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.file(
                        _profileImage!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'Appuyez pour prendre une photo',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 30),

          // Photo pour reconnaissance faciale
          const Text(
            'Photo reconnaissance faciale',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Cette photo sera utilisée pour vous authentifier',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: _takeFacePhoto,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: kPrimaryColor, width: 2, style: BorderStyle.solid),
              ),
              child: _faceImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.file(
                        _faceImage!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.face, size: 50, color: kPrimaryColor),
                        SizedBox(height: 10),
                        Text(
                          'Photo pour reconnaissance faciale',
                          style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildVerificationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vérification',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Vérifiez vos informations avant de terminer',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),

          _buildVerificationCard(
            title: 'Informations personnelles',
            content: [
              'Nom: ${_firstNameController.text} ${_lastNameController.text}',
              'Carte: ${_cardNumberController.text}',
              'Téléphone: ${_phoneController.text}',
              'Email: ${_emailController.text}',
            ],
          ),

          const SizedBox(height: 20),

          _buildVerificationCard(
            title: 'Services (${_selectedServices.length})',
            content: _selectedServices,
          ),

          const SizedBox(height: 20),

          _buildVerificationCard(
            title: 'Tarifs',
            content: _priceList.entries
                .map((entry) => '${entry.key}: ${entry.value} DA/h')
                .toList(),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: kSuccessColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kSuccessColor.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: kSuccessColor),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Votre inscription sera vérifiée sous 24h. Vous recevrez une notification de confirmation.',
                    style: TextStyle(
                      color: kSuccessColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard({
    required String title,
    required List<String> content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          ...content.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              '• $item',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kPrimaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          labelStyle: TextStyle(color: Colors.grey[600]),
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSecondaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kPrimaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Précédent',
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          
          if (_currentStep > 0) const SizedBox(width: 15),
          
          Expanded(
            flex: _currentStep > 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: kSecondaryColor,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep < 4 ? 'Suivant' : 'Terminer',
                      style: const TextStyle(
                        color: kSecondaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}


// KHIDMETI APP - DÉVELOPPEMENT DE LA CLASSE : SearchScreen

// ===== SEARCH SCREEN =====
class SearchScreen extends StatefulWidget {
    
    const SearchScreen({Key? key, this.workers}) : super(key: key);
    final List<WorkerModel>? workers;
  @override
  _SearchScreenState createState() => _SearchScreenState();
}
class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String _selectedService = '';
  List<WorkerModel> _workers = [];
  List<WorkerModel> _filteredWorkers = [];
  bool _isLoading = false;
  bool _showFilters = false;
  
  // Filtres
  double _maxDistance = 10.0; // km
  double _minRating = 0.0;
  double _maxPrice = 10000.0;
  String _sortBy = 'distance'; // distance, rating, price
  bool _onlineOnly = true;
  
  LatLng? _userLocation;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    
    _getUserLocation();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    setState(() => _isLoading = true);
    
    final position = await LocationService().getCurrentPosition();
    if (position != null) {
      _userLocation = LatLng(position.latitude, position.longitude);
      if (_selectedService.isNotEmpty) {
        await _searchWorkers();
      }
    }
    
    setState(() => _isLoading = false);
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredWorkers = _workers;
      });
    } else {
      _filterWorkers();
    }
  }

  Future<void> _searchWorkers() async {
    if (_userLocation == null || _selectedService.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final workers = await DatabaseService().getNearbyWorkers(
        _userLocation!,
        _selectedService,
        _maxDistance,
      );

      setState(() {
        _workers = workers;
        _filteredWorkers = workers;
      });
      _filterWorkers();
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la recherche: ${e.toString()}');
    }

    setState(() => _isLoading = false);
  }

  void _filterWorkers() {
    List<WorkerModel> filtered = List.from(_workers);

    // Filtre par nom/recherche
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((worker) {
        return worker.firstName.toLowerCase().contains(query) ||
               worker.lastName.toLowerCase().contains(query) ||
               worker.services.any((service) => service.toLowerCase().contains(query));
      }).toList();
    }

    // Filtre par rating
    if (_minRating > 0) {
      filtered = filtered.where((worker) => worker.rating >= _minRating).toList();
    }

    // Filtre par prix (si disponible dans priceList)
    if (_maxPrice < 10000) {
      filtered = filtered.where((worker) {
        if (worker.priceList == null || worker.priceList!.isEmpty) return true;
        final servicePrice = worker.priceList![_selectedService];
        return servicePrice == null || servicePrice <= _maxPrice;
      }).toList();
    }

    // Filtre en ligne uniquement
    if (_onlineOnly) {
      filtered = filtered.where((worker) => worker.isOnline).toList();
    }

    // Tri
    _sortWorkers(filtered);

    setState(() {
      _filteredWorkers = filtered;
    });
  }

  void _sortWorkers(List<WorkerModel> workers) {
    switch (_sortBy) {
      case 'distance':
        if (_userLocation != null) {
          workers.sort((a, b) {
            if (a.currentLocation == null || b.currentLocation == null) return 0;
            final distanceA = LocationService().calculateDistance(_userLocation!, a.currentLocation!);
            final distanceB = LocationService().calculateDistance(_userLocation!, b.currentLocation!);
            return distanceA.compareTo(distanceB);
          });
        }
        break;
      case 'rating':
        workers.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'price':
        workers.sort((a, b) {
          final priceA = a.priceList?[_selectedService] ?? double.maxFinite;
          final priceB = b.priceList?[_selectedService] ?? double.maxFinite;
          return priceA.compareTo(priceB);
        });
        break;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kErrorColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kSuccessColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildSearchHeader(),
            if (_showFilters) _buildFiltersPanel(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingWidget()
                  : _selectedService.isEmpty
                      ? _buildServiceSelection()
                      : _buildWorkersList(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kPrimaryColor,
      elevation: 0,
      title: Text(
        'Rechercher un service',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.map, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MapScreen(
                  userLocation: _userLocation,
                  workers: _filteredWorkers,
                  selectedService: _selectedService,
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: Icon(
            _showFilters ? Icons.filter_list_off : Icons.filter_list,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() => _showFilters = !_showFilters);
          },
        ),
      ],
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          // Barre de recherche
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou service...',
                prefixIcon: Icon(Icons.search, color: kPrimaryColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          SizedBox(height: 16),
          
          // Service sélectionné
          if (_selectedService.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kAccentColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.build, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    _selectedService,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedService = '';
                        _workers.clear();
                        _filteredWorkers.clear();
                      });
                    },
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtres',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          SizedBox(height: 16),
          
          // Distance maximale
          Row(
            children: [
              Expanded(
                child: Text('Distance max: ${_maxDistance.toInt()} km'),
              ),
              Expanded(
                flex: 2,
                child: Slider(
                  value: _maxDistance,
                  min: 1.0,
                  max: 50.0,
                  divisions: 49,
                  activeColor: kPrimaryColor,
                  onChanged: (value) {
                    setState(() => _maxDistance = value);
                    _filterWorkers();
                  },
                ),
              ),
            ],
          ),
          
          // Rating minimum
          Row(
            children: [
              Expanded(
                child: Text('Note min: ${_minRating.toStringAsFixed(1)}⭐'),
              ),
              Expanded(
                flex: 2,
                child: Slider(
                  value: _minRating,
                  min: 0.0,
                  max: 5.0,
                  divisions: 50,
                  activeColor: kPrimaryColor,
                  onChanged: (value) {
                    setState(() => _minRating = value);
                    _filterWorkers();
                  },
                ),
              ),
            ],
          ),
          
          // Tri par
          Row(
            children: [
              Text('Trier par: '),
              SizedBox(width: 8),
              DropdownButton<String>(
                value: _sortBy,
                items: [
                  DropdownMenuItem(value: 'distance', child: Text('Distance')),
                  DropdownMenuItem(value: 'rating', child: Text('Note')),
                  DropdownMenuItem(value: 'price', child: Text('Prix')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _sortBy = value);
                    _filterWorkers();
                  }
                },
              ),
              Spacer(),
              // En ligne seulement
              Row(
                children: [
                  Text('En ligne'),
                  Switch(
                    value: _onlineOnly,
                    activeColor: kPrimaryColor,
                    onChanged: (value) {
                      setState(() => _onlineOnly = value);
                      _filterWorkers();
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSelection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choisissez un service',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Sélectionnez le type de service dont vous avez besoin',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: kServices.length,
              itemBuilder: (context, index) {
                final service = kServices[index];
                return _buildServiceCard(service);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(String service) {
    final serviceIcons = {
      'Plomberie': Icons.plumbing,
      'Électricité': Icons.electrical_services,
      'Nettoyage': Icons.cleaning_services,
      'Livraison': Icons.delivery_dining,
      'Peinture': Icons.format_paint,
      'Réparation électroménager': Icons.home_repair_service,
      'Maçonnerie': Icons.construction,
      'Climatisation': Icons.ac_unit,
      'Baby-sitting': Icons.child_care,
      'Cours particuliers': Icons.school,
    };

    return GestureDetector(
      onTap: () {
        setState(() => _selectedService = service);
        _searchWorkers();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              serviceIcons[service] ?? Icons.build,
              size: 32,
              color: kPrimaryColor,
            ),
            SizedBox(height: 8),
            Text(
              service,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildWorkersList() {
    if (_filteredWorkers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Aucun travailleur trouvé',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Essayez d\'ajuster vos filtres',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: kPrimaryColor,
      onRefresh: _searchWorkers,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        itemCount: _filteredWorkers.length,
        itemBuilder: (context, index) {
          final worker = _filteredWorkers[index];
          return _buildWorkerCard(worker);
        },
      ),
    );
  }

  Widget _buildWorkerCard(WorkerModel worker) {
    final distance = _userLocation != null && worker.currentLocation != null
        ? LocationService().calculateDistance(_userLocation!, worker.currentLocation!) / 1000
        : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailScreen(worker: worker, serviceType: _selectedService, userLocation: _userLocation!),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Photo de profil
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: kPrimaryColor.withOpacity(0.1),
                        backgroundImage: worker.profileImageUrl != null
                            ? CachedNetworkImageProvider(worker.profileImageUrl!)
                            : null,
                        child: worker.profileImageUrl == null
                            ? Icon(Icons.person, size: 35, color: kPrimaryColor)
                            : null,
                      ),
                      if (worker.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: kSuccessColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 16),
                  
                  // Informations du travailleur
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${worker.firstName} ${worker.lastName}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            if (worker.isVerified)
                              Icon(Icons.verified, color: kPrimaryColor, size: 20),
                          ],
                        ),
                        SizedBox(height: 4),
                        
                        // Rating et distance
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '${worker.rating.toStringAsFixed(1)} (${worker.totalRatings})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(width: 16),
                            Icon(Icons.location_on, color: kPrimaryColor, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '${distance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        
                        // Services proposés
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: worker.services.take(3).map((service) {
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                service,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: kPrimaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Ouvrir le chat
                        final chatId = '${AuthService().currentUser?.uid}_${worker.uid}';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatDetailScreen(
  chatId: chatId,
  otherUserId: worker.uid,
  otherUserName: '${worker.firstName} ${worker.lastName}',
  otherUserImageUrl: worker.profileImageUrl ?? '',
  selectedWorker: worker,
  serviceType: _selectedService,
  isWorker: true, // لأن المستخدم الآخر هو عامل
),
                          ),
                        );
                      },
                      icon: Icon(Icons.chat, color: kPrimaryColor),
                      label: Text('Chat', style: TextStyle(color: kPrimaryColor)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kPrimaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ServiceDetailScreen(worker: worker, serviceType: _selectedService, userLocation: _userLocation!),

                          ),
                        );
                      },
                      icon: Icon(Icons.build, color: Colors.white),
                      label: Text('Demander', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Recherche en cours...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}


// ===== REQUESTS SCREEN =====
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({Key? key}) : super(key: key);

  @override
  _RequestsScreenState createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isWorker = false;
  String? _currentUserId;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isWorker ? 3 : 2, vsync: this);
    _initializeUserType();
  }

  Future<void> _initializeUserType() async {
    final prefs = await SharedPreferences.getInstance();
    final isWorker = prefs.getBool(kWorkerStatusKey) ?? false;
    final currentUser = _authService.currentUser;
    
    setState(() {
      _isWorker = isWorker;
      _currentUserId = currentUser?.uid;
      _tabController = TabController(length: _isWorker ? 3 : 2, vsync: this);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(
          child: LoadingWidget(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kSecondaryColor,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        title: const Text(
          'Mes Demandes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _isWorker ? [
            const Tab(text: 'Reçues'),
            const Tab(text: 'Acceptées'),
            const Tab(text: 'Historique'),
          ] : [
            const Tab(text: 'En cours'),
            const Tab(text: 'Historique'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _isWorker ? [
          _buildReceivedRequestsTab(),
          _buildAcceptedRequestsTab(),
          _buildHistoryTab(),
        ] : [
          _buildActiveRequestsTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: !_isWorker ? FloatingActionButton(
        onPressed: () => _showCreateRequestDialog(context),
        backgroundColor: kAccentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  // Onglet demandes reçues (pour travailleurs)
  Widget _buildReceivedRequestsTab() {
    return StreamBuilder<List<RequestModel>>(
      stream: _getReceivedRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            'Aucune demande reçue',
            'Les nouvelles demandes apparaîtront ici',
            Icons.inbox_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final request = snapshot.data![index];
            return RequestCard(
  request: request,
  isWorker: true,
  isHistory: false, // <-- الإضافة هنا
  onComplete: () => _completeRequest(request),
  onTap: () => _openRequestDetail(request),
);
          },
        );
      },
    );
  }

  // Onglet demandes acceptées (pour travailleurs)
  Widget _buildAcceptedRequestsTab() {
    return StreamBuilder<List<RequestModel>>(
      stream: _getWorkerAcceptedRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            'Aucune demande acceptée',
            'Les demandes que vous acceptez apparaîtront ici',
            Icons.work_outline,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final request = snapshot.data![index];
            return RequestCard(
  request: request,
  isWorker: false,
  isHistory: false, // <-- الإضافة هنا
  onCancel: () => _cancelRequest(request),
  onTap: () => _openRequestDetail(request),
);
          },
        );
      },
    );
  }

  // Onglet demandes actives (pour utilisateurs)
  Widget _buildActiveRequestsTab() {
    return StreamBuilder<List<RequestModel>>(
      stream: _databaseService.getUserRequests(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            'Aucune demande active',
            'Créez votre première demande de service',
            Icons.add_task,
          );
        }

        final activeRequests = snapshot.data!.where((r) =>
          r.status != RequestStatus.completed &&
          r.status != RequestStatus.cancelled
        ).toList();

        if (activeRequests.isEmpty) {
          return _buildEmptyState(
            'Aucune demande active',
            'Toutes vos demandes sont terminées',
            Icons.done_all,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeRequests.length,
          itemBuilder: (context, index) {
            final request = activeRequests[index];
            return RequestCard(
  request: request,
  isWorker: false,
  isHistory: false, // <-- Add this line
  onCancel: () => _cancelRequest(request),
  onTap: () => _openRequestDetail(request),
);
          },
        );
      }
    );
  }

  // Onglet historique
  Widget _buildHistoryTab() {
    final stream = _isWorker 
        ? _getWorkerCompletedRequests()
        : _getUserCompletedRequests();

    return StreamBuilder<List<RequestModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            'Aucun historique',
            'L\'historique de vos services apparaîtra ici',
            Icons.history,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final request = snapshot.data![index];
            return RequestCard(
              request: request,
              isWorker: _isWorker,
              isHistory: true,
              onRate: !_isWorker && request.rating == null ? () => _rateRequest(request) : null,
              onTap: () => _openRequestDetail(request),
            );
          },
        );
      },
    );
  }

  // État vide
  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Streams pour récupérer les données
  Stream<List<RequestModel>> _getReceivedRequests() {
    // Récupérer les demandes proches du travailleur
    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<RequestModel> nearbyRequests = [];
      
      // Obtenir la position du travailleur
      final worker = await _databaseService.getWorker(_currentUserId!);
      if (worker?.currentLocation == null) return nearbyRequests;

      for (var doc in snapshot.docs) {
        final request = RequestModel.fromMap(doc.data());
        
        // Vérifier si le service correspond
        if (!worker!.services.contains(request.serviceType)) continue;
        
        // Vérifier la distance (rayon de 10km)
        double distance = LocationService().calculateDistance(
          worker.currentLocation!,
          request.location,
        );
        
        if (distance <= 10000) { // 10km en mètres
          nearbyRequests.add(request);
        }
      }
      
      return nearbyRequests;
    });
  }

  Stream<List<RequestModel>> _getWorkerAcceptedRequests() {
    return _firestore
        .collection('requests')
        .where('workerId', isEqualTo: _currentUserId)
        .where('status', whereIn: ['accepted', 'inProgress'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data()))
            .toList());
  }

  Stream<List<RequestModel>> _getWorkerCompletedRequests() {
    return _firestore
        .collection('requests')
        .where('workerId', isEqualTo: _currentUserId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data()))
            .toList());
  }

  Stream<List<RequestModel>> _getUserCompletedRequests() {
    return _firestore
        .collection('requests')
        .where('userId', isEqualTo: _currentUserId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data()))
            .toList());
  }

  // Actions sur les demandes
  Future<void> _acceptRequest(RequestModel request) async {
    try {
      await _databaseService.updateRequestStatus(
        request.id,
        RequestStatus.accepted,
        workerId: _currentUserId,
      );
      
      // Envoyer notification au client
      await NotificationService().sendNotificationToUser(
        request.userId,
        'Demande acceptée',
        'Un travailleur a accepté votre demande de ${request.serviceType}',
        {'requestId': request.id, 'type': 'request_accepted'},
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demande acceptée avec succès'),
          backgroundColor: kSuccessColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: kErrorColor,
        ),
      );
    }
  }

  Future<void> _rejectRequest(RequestModel request) async {
    // Simplement ne rien faire, la demande reste disponible pour d'autres travailleurs
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demande ignorée'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  Future<void> _completeRequest(RequestModel request) async {
    try {
      await _databaseService.updateRequestStatus(request.id, RequestStatus.completed);
      
      // Envoyer notification au client
      await NotificationService().sendNotificationToUser(
        request.userId,
        'Service terminé',
        'Votre demande de ${request.serviceType} est terminée',
        {'requestId': request.id, 'type': 'request_completed'},
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service marqué comme terminé'),
          backgroundColor: kSuccessColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: kErrorColor,
        ),
      );
    }
  }

  Future<void> _cancelRequest(RequestModel request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la demande'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette demande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui', style: TextStyle(color: kErrorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseService.updateRequestStatus(request.id, RequestStatus.cancelled);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande annulée'),
            backgroundColor: kErrorColor,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: kErrorColor,
          ),
        );
      }
    }
  }

  // Évaluer une demande terminée
  Future<void> _rateRequest(RequestModel request) async {
    double rating = 5.0;
    String review = '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Évaluer le service'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Votre note :'),
              const SizedBox(height: 8),
              RatingBar.builder(
                initialRating: rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemSize: 30,
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: kAccentColor,
                ),
                onRatingUpdate: (r) => setState(() => rating = r),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Commentaire (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => review = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {'rating': rating, 'review': review}),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (result != null && request.workerId != null) {
      try {
        // Mettre à jour la demande avec l'évaluation
        await _firestore.collection('requests').doc(request.id).update({
          'rating': result['rating'],
          'review': result['review'],
        });

        // Mettre à jour la note du travailleur
        await _databaseService.rateWorker(
          request.workerId!,
          result['rating'],
          result['review'],
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Évaluation enregistrée'),
            backgroundColor: kSuccessColor,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: kErrorColor,
          ),
        );
      }
    }
  }

  // Ouvrir le détail d'une demande
  void _openRequestDetail(RequestModel request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceDetailScreen(
  request: request,
  serviceType: request.serviceType,
  userLocation: request.location,
),
      ),
    );
  }

  // Dialog pour créer une nouvelle demande
  void _showCreateRequestDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRequestScreen(),
      ),
    );
  }
}

// Écran de création de demande

class CreateRequestScreen extends StatefulWidget {
  final WorkerModel? selectedWorker;
  final LatLng? userLocation;

  const CreateRequestScreen({
    Key? key,
    this.selectedWorker,
    this.userLocation,
  }) : super(key: key);

    
  @override
  _CreateRequestScreenState createState() => _CreateRequestScreenState();
}
class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  
  String? _selectedService;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  List<File> _mediaFiles = [];
  bool _isUrgent = false;
  DateTime? _scheduledDate;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSecondaryColor,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        title: const Text('Nouvelle Demande', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildServiceSelector(),
            const SizedBox(height: 16),
            _buildTitleField(),
            const SizedBox(height: 16),
            _buildDescriptionField(),
            const SizedBox(height: 16),
            _buildLocationSelector(),
            const SizedBox(height: 16),
            _buildMediaSelector(),
            const SizedBox(height: 16),
            _buildBudgetField(),
            const SizedBox(height: 16),
            _buildUrgentSwitch(),
            const SizedBox(height: 16),
            _buildScheduleDateSelector(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedService,
      decoration: const InputDecoration(
        labelText: 'Type de service',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.build),
      ),
      items: kServices.map((service) => DropdownMenuItem(
        value: service,
        child: Text(service),
      )).toList(),
      onChanged: (value) => setState(() => _selectedService = value),
      validator: (value) => value == null ? 'Sélectionnez un service' : null,
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Titre de la demande',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.title),
      ),
      validator: (value) => value?.isEmpty == true ? 'Titre requis' : null,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description détaillée',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.description),
      ),
      maxLines: 4,
      validator: (value) => value?.isEmpty == true ? 'Description requise' : null,
    );
  }

  Widget _buildLocationSelector() {
    return InkWell(
      onTap: _selectLocation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _selectedLocation != null
                    ? _selectedAddress.isNotEmpty ? _selectedAddress : 'Localisation sélectionnée'
                    : 'Sélectionner la localisation',
                style: TextStyle(
                  color: _selectedLocation != null ? Colors.black : Colors.grey[600],
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Ajouter photos/vidéos'),
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            ),
          ],
        ),
        if (_mediaFiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _mediaFiles.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(_mediaFiles[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() => _mediaFiles.removeAt(index));
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBudgetField() {
    return TextFormField(
      controller: _budgetController,
      decoration: const InputDecoration(
        labelText: 'Budget estimé (DA)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.monetization_on),
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildUrgentSwitch() {
    return SwitchListTile(
      title: const Text('Urgent'),
      subtitle: const Text('Demande prioritaire'),
      value: _isUrgent,
      onChanged: (value) => setState(() => _isUrgent = value),
      activeColor: kAccentColor,
    );
  }

  Widget _buildScheduleDateSelector() {
    return InkWell(
      onTap: _selectScheduleDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _scheduledDate != null
                    ? 'Prévu pour: ${DateFormat('dd/MM/yyyy à HH:mm').format(_scheduledDate!)}'
                    : 'Programmer pour plus tard (optionnel)',
                style: TextStyle(
                  color: _scheduledDate != null ? Colors.black : Colors.grey[600],
                ),
              ),
            ),
            if (_scheduledDate != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _scheduledDate = null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccentColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              'Publier la demande',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
    );
  }

  Future<void> _selectLocation() async {
    final location = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (context) => MapScreen(selectLocation: true, workers: [])),
    );

    if (location != null) {
      final address = await LocationService().getAddressFromCoordinates(location);
      setState(() {
        _selectedLocation = location;
        _selectedAddress = address;
      });
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultipleMedia();
    
    setState(() {
      _mediaFiles.addAll(pickedFiles.map((e) => File(e.path)));
    });
  }

  Future<void> _selectScheduleDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _scheduledDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs requis'),
          backgroundColor: kErrorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) throw Exception('Utilisateur non connecté');

      // Upload des médias
      List<String> mediaUrls = [];
      if (_mediaFiles.isNotEmpty) {
        final requestId = DateTime.now().millisecondsSinceEpoch.toString();
        mediaUrls = await StorageService().uploadRequestMedia(requestId, _mediaFiles);
      }

      // Créer la demande
      final request = RequestModel(
        id: '',
        userId: currentUser.uid,
        serviceType: _selectedService!,
        title: _titleController.text,
        description: _descriptionController.text,
        location: _selectedLocation!,
        address: _selectedAddress,
        mediaUrls: mediaUrls,
        budget: _budgetController.text.isNotEmpty 
            ? double.tryParse(_budgetController.text)
            : null,
        createdAt: DateTime.now(),
        scheduledDate: _scheduledDate,
        isUrgent: _isUrgent,
      );

      await DatabaseService().createRequest(request);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demande créée avec succès'),
          backgroundColor: kSuccessColor,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: kErrorColor,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }
}


// KHIDMETI APP - DÉVELOPPEMENT DE LA CLASSE : ChatScreen

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _chatList = [];
  bool _isLoading = true;
  String? _currentUserId;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    // Écouter les changements d'authentification
    _authSubscription = AuthService().authStateChanges.listen((user) {
      if (user != null) {
        setState(() {
          _currentUserId = user.uid;
        });
        _loadChatList();
      } else {
        setState(() {
          _currentUserId = null;
          _chatList = [];
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadChatList() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer les demandes de l'utilisateur avec un travailleur assigné
      final userRequestsSnapshot = await _firestore
          .collection('requests')
          .where('userId', isEqualTo: _currentUserId)
          .where('workerId', isNotEqualTo: '')
          .get();

      // Récupérer les demandes où l'utilisateur est le travailleur
      final workerRequestsSnapshot = await _firestore
          .collection('requests')
          .where('workerId', isEqualTo: _currentUserId)
          .get();

      List<Map<String, dynamic>> chats = [];
      Set<String> processedChats = {};

      // Traiter les demandes utilisateur
      for (var doc in userRequestsSnapshot.docs) {
        final request = RequestModel.fromMap(doc.data());
        if (request.workerId != null && request.workerId!.isNotEmpty) {
          String chatId = _generateChatId(request.userId, request.workerId!);
          
          if (!processedChats.contains(chatId)) {
            final workerData = await DatabaseService().getWorker(request.workerId!);
            if (workerData != null) {
              final lastMessage = await _getLastMessage(chatId);
              
              chats.add({
                'chatId': chatId,
                'requestId': request.id,
                'otherUserId': request.workerId!,
                'otherUserName': '${workerData.firstName} ${workerData.lastName}',
                'otherUserImage': workerData.profileImageUrl,
                'serviceType': request.serviceType,
                'lastMessage': lastMessage?['message'] ?? 'Nouveau chat',
                'lastMessageTime': lastMessage?['timestamp'] ?? request.createdAt,
                'isRead': lastMessage?['isRead'] ?? true,
                'userType': 'client',
                'selectedWorker': workerData,
              });
              processedChats.add(chatId);
            }
          }
        }
      }

      // Traiter les demandes travailleur
      for (var doc in workerRequestsSnapshot.docs) {
        final request = RequestModel.fromMap(doc.data());
        String chatId = _generateChatId(request.userId, request.workerId ?? _currentUserId!);
        
        if (!processedChats.contains(chatId)) {
          final userData = await DatabaseService().getUser(request.userId);
          if (userData != null) {
            final lastMessage = await _getLastMessage(chatId);
            
            chats.add({
              'chatId': chatId,
              'requestId': request.id,
              'otherUserId': request.userId,
              'otherUserName': '${userData.firstName} ${userData.lastName}',
              'otherUserImage': userData.profileImageUrl,
              'serviceType': request.serviceType,
              'lastMessage': lastMessage?['message'] ?? 'Nouveau chat',
              'lastMessageTime': lastMessage?['timestamp'] ?? request.createdAt,
              'isRead': lastMessage?['isRead'] ?? true,
              'userType': 'worker',
            });
            processedChats.add(chatId);
          }
        }
      }

      // Trier par date du dernier message
      chats.sort((a, b) => (b['lastMessageTime'] as DateTime)
          .compareTo(a['lastMessageTime'] as DateTime));

      setState(() {
        _chatList = chats;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement liste chat: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _generateChatId(String userId1, String userId2) {
    // Générer un ID de chat unique et cohérent
    List<String> ids = [userId1, userId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<Map<String, dynamic>?> _getLastMessage(String chatId) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final message = ChatMessage.fromMap(snapshot.docs.first.data());
        return {
          'message': message.message,
          'timestamp': message.timestamp,
          'isRead': message.isRead || message.senderId == _currentUserId,
        };
      }
    } catch (e) {
      print('Erreur récupération dernier message: $e');
    }
    return null;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return difference.inDays == 1 ? 'Hier' : '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'Maintenant';
    }
  }

  void _openChatDetail(Map<String, dynamic> chatData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
  chatId: chatData['chatId'],
  otherUserId: chatData['otherUserId'],
  otherUserName: chatData['otherUserName'],
  otherUserImageUrl: chatData['otherUserImage'],
  serviceType: chatData['serviceType'],
  selectedWorker: chatData['selectedWorker'], // <-- أضف هذا السطر
  isWorker: chatData['userType'] == 'worker', // <-- أضف هذا السطر
),
      ),
    ).then((_) {
      // Recharger la liste après retour du chat
      _loadChatList();
    });
  }

  Widget _buildChatItem(Map<String, dynamic> chatData) {
    final bool hasUnreadMessage = !(chatData['isRead'] as bool);
    final DateTime lastMessageTime = chatData['lastMessageTime'] as DateTime;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: kSecondaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: kPrimaryColor.withOpacity(0.3),
              backgroundImage: chatData['otherUserImage'] != null
                  ? CachedNetworkImageProvider(chatData['otherUserImage'])
                  : null,
              child: chatData['otherUserImage'] == null
                  ? Icon(
                      Icons.person,
                      color: kPrimaryColor,
                      size: 28,
                    )
                  : null,
            ),
            if (hasUnreadMessage)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: kAccentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: kSecondaryColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                chatData['otherUserName'],
                style: TextStyle(
                  fontWeight: hasUnreadMessage ? FontWeight.bold : FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatTime(lastMessageTime),
              style: TextStyle(
                fontSize: 12,
                color: hasUnreadMessage ? kAccentColor : Colors.grey[600],
                fontWeight: hasUnreadMessage ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                chatData['serviceType'],
                style: TextStyle(
                  fontSize: 11,
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 6),
            Text(
              chatData['lastMessage'],
              style: TextStyle(
                fontSize: 14,
                color: hasUnreadMessage ? Colors.black87 : Colors.grey[600],
                fontWeight: hasUnreadMessage ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: kPrimaryColor,
          size: 24,
        ),
        onTap: () => _openChatDetail(chatData),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Aucune conversation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Vos conversations apparaîtront ici\nune fois que vous aurez interagi avec des travailleurs',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigation vers l'onglet recherche
              DefaultTabController.of(context)?.animateTo(1);
            },
            icon: Icon(Icons.search),
            label: Text('Trouver un service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: kSecondaryColor,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: kSecondaryColor,
          ),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: kSecondaryColor),
            onPressed: _loadChatList,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chargement des conversations...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _currentUserId == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Connexion requise',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Connectez-vous pour accéder à vos messages',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : _chatList.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadChatList,
                      color: kPrimaryColor,
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        itemCount: _chatList.length,
                        itemBuilder: (context, index) {
                          return _buildChatItem(_chatList[index]);
                        },
                      ),
                    ),
    );
  }
}


// KHIDMETI APP - DÉVELOPPEMENT DE LA CLASSE : ProfileScreen

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}
class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  UserModel? _currentUser;
  WorkerModel? _currentWorker;
  bool _isLoading = true;
  bool _isWorker = false;
  bool _isEditing = false;
  
  // Contrôleurs pour l'édition
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // Charger le profil utilisateur
  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _isWorker = prefs.getBool(kWorkerStatusKey) ?? false;
      
      final currentUser = AuthService().currentUser;
      if (currentUser != null) {
        if (_isWorker) {
          _currentWorker = await DatabaseService().getWorker(currentUser.uid);
          if (_currentWorker != null) {
            _firstNameController.text = _currentWorker!.firstName;
            _lastNameController.text = _currentWorker!.lastName;
            _phoneController.text = _currentWorker!.phoneNumber;
            _bioController.text = _currentWorker!.bio ?? '';
          }
        } else {
          _currentUser = await DatabaseService().getUser(currentUser.uid);
          if (_currentUser != null) {
            _firstNameController.text = _currentUser!.firstName;
            _lastNameController.text = _currentUser!.lastName;
            _phoneController.text = _currentUser!.phoneNumber ?? '';
          }
        }
      }
    } catch (e) {
      print('Erreur chargement profil: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement du profil'),
          backgroundColor: kErrorColor,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Sélectionner et uploader une photo de profil
  Future<void> _pickAndUploadProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      
      if (image != null) {
        // Afficher un indicateur de chargement
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(child: CircularProgressIndicator()),
        );
        
        final currentUser = AuthService().currentUser;
        if (currentUser != null) {
          final imageUrl = await StorageService().uploadProfileImage(
            currentUser.uid,
            File(image.path),
          );
          
          if (imageUrl != null) {
            // Mettre à jour la base de données
            if (_isWorker && _currentWorker != null) {
              await _firestore.collection('workers').doc(currentUser.uid).update({
                'profileImageUrl': imageUrl,
              });
              setState(() {
                _currentWorker = _currentWorker!.copyWith(profileImageUrl: imageUrl);
              });
            } else if (_currentUser != null) {
              await _firestore.collection('users').doc(currentUser.uid).update({
                'profileImageUrl': imageUrl,
              });
              setState(() {
                _currentUser = _currentUser!.copyWith(profileImageUrl: imageUrl);
              });
            }
            
            Navigator.pop(context); // Fermer le dialogue
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Photo de profil mise à jour !'),
                backgroundColor: kSuccessColor,
              ),
            );
          } else {
            Navigator.pop(context);
            throw Exception('Échec de l\'upload');
          }
        }
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour de la photo'),
          backgroundColor: kErrorColor,
        ),
      );
    }
  }

  // Sauvegarder les modifications du profil
  Future<void> _saveProfile() async {
    if (_firstNameController.text.trim().isEmpty || 
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prénom et nom sont obligatoires'),
          backgroundColor: kErrorColor,
        ),
      );
      return;
    }

    try {
      final currentUser = AuthService().currentUser;
      if (currentUser != null) {
        Map<String, dynamic> updates = {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
        };

        if (_isWorker) {
          updates['bio'] = _bioController.text.trim();
          await _firestore.collection('workers').doc(currentUser.uid).update(updates);
        } else {
          await _firestore.collection('users').doc(currentUser.uid).update(updates);
        }

        setState(() => _isEditing = false);
        await _loadUserProfile(); // Recharger les données
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil mis à jour avec succès !'),
            backgroundColor: kSuccessColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde'),
          backgroundColor: kErrorColor,
        ),
      );
    }
  }

  // Déconnexion
  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Déconnexion'),
        content: Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Text('Déconnexion', style: TextStyle(color: kErrorColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kSecondaryColor,
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: kSecondaryColor,
      appBar: AppBar(
        title: Text(
          'Mon Profil',
          style: TextStyle(
            color: kSecondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: Icon(Icons.edit, color: kSecondaryColor),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'Sauver',
                style: TextStyle(
                  color: kSecondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Photo de profil
            _buildProfileImageSection(),
            
            SizedBox(height: 30),
            
            // Informations personnelles
            _buildPersonalInfoSection(),
            
            SizedBox(height: 30),
            
            // Section spécifique aux travailleurs
            if (_isWorker) _buildWorkerSection(),
            
            SizedBox(height: 30),
            
            // Options du compte
            _buildAccountOptionsSection(),
            
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Section photo de profil
  Widget _buildProfileImageSection() {
    String? imageUrl = _isWorker ? _currentWorker?.profileImageUrl : _currentUser?.profileImageUrl;
    
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kPrimaryColor, width: 3),
            ),
            child: ClipOval(
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.person, size: 50, color: Colors.grey),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.person, size: 50, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.person, size: 50, color: Colors.grey),
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickAndUploadProfileImage,
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: kAccentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: kSecondaryColor, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: kSecondaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section informations personnelles
  Widget _buildPersonalInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations personnelles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            SizedBox(height: 20),
            
            // Prénom
            _buildTextField(
              controller: _firstNameController,
              label: 'Prénom',
              icon: Icons.person,
              enabled: _isEditing,
            ),
            
            SizedBox(height: 15),
            
            // Nom
            _buildTextField(
              controller: _lastNameController,
              label: 'Nom',
              icon: Icons.person_outline,
              enabled: _isEditing,
            ),
            
            SizedBox(height: 15),
            
            // Téléphone
            _buildTextField(
              controller: _phoneController,
              label: 'Téléphone',
              icon: Icons.phone,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
            ),
            
            SizedBox(height: 15),
            
            // Email (non modifiable)
            _buildTextField(
              controller: TextEditingController(
                text: _isWorker ? _currentWorker?.email : _currentUser?.email,
              ),
              label: 'Email',
              icon: Icons.email,
              enabled: false,
            ),
            
            if (_isWorker) ...[
              SizedBox(height: 15),
              
              // Bio (uniquement pour les travailleurs)
              _buildTextField(
                controller: _bioController,
                label: 'Biographie',
                icon: Icons.description,
                enabled: _isEditing,
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Section spécifique aux travailleurs
  Widget _buildWorkerSection() {
    if (_currentWorker == null) return SizedBox.shrink();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profil travailleur',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            SizedBox(height: 20),
            
            // Services proposés
            _buildInfoRow(
              icon: Icons.work,
              label: 'Services',
              value: _currentWorker!.services.join(', '),
            ),
            
            SizedBox(height: 15),
            
            // Note et évaluations
            _buildInfoRow(
              icon: Icons.star,
              label: 'Évaluation',
              value: '${_currentWorker!.rating.toStringAsFixed(1)} ⭐ (${_currentWorker!.totalRatings} avis)',
            ),
            
            SizedBox(height: 15),
            
            // Statut d'abonnement
            _buildInfoRow(
              icon: _currentWorker!.isSubscribed ? Icons.check_circle : Icons.warning,
              label: 'Abonnement',
              value: _currentWorker!.isSubscribed ? 'Actif' : 'Expiré',
              valueColor: _currentWorker!.isSubscribed ? kSuccessColor : kErrorColor,
            ),
            
            if (_currentWorker!.isSubscribed && _currentWorker!.subscriptionEndDate != null) ...[
              SizedBox(height: 15),
              _buildInfoRow(
                icon: Icons.schedule,
                label: 'Expire le',
                value: DateFormat('dd/MM/yyyy').format(_currentWorker!.subscriptionEndDate!),
              ),
            ],
            
            SizedBox(height: 20),
            
            // Bouton vers abonnement
            if (!_currentWorker!.isSubscribed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/subscription');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text(
                    'Renouveler l\'abonnement',
                    style: TextStyle(
                      color: kSecondaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  // Section options du compte
  Widget _buildAccountOptionsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.history, color: kPrimaryColor),
            title: Text('Historique des services'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigation vers l'historique
            },
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.notifications, color: kPrimaryColor),
            title: Text('Notifications'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigation vers les paramètres de notifications
            },
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.help, color: kPrimaryColor),
            title: Text('Aide & Support'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigation vers l'aide
            },
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.info, color: kPrimaryColor),
            title: Text('À propos'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigation vers à propos
            },
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: kErrorColor),
            title: Text(
              'Déconnexion',
              style: TextStyle(color: kErrorColor),
            ),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }

  // Widget pour les champs de texte
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: enabled ? kPrimaryColor : Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: kPrimaryColor, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        filled: !enabled,
        fillColor: Colors.grey.shade100,
      ),
    );
  }

  // Widget pour afficher les informations
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kPrimaryColor, size: 20),
        SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: valueColor ?? Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// KHIDMETI APP - DÉVELOPPEMENT DE LA CLASSE : ServiceDetailScreen

class ServiceDetailScreen extends StatefulWidget {
  final String serviceType;
  final LatLng userLocation;
  final String? serviceName;
  final String? service;
  final WorkerModel? worker;
  final RequestModel? request;

  const ServiceDetailScreen({
  Key? key,
  this.service,
  this.worker,
  this.request,
  this.serviceName,
  required this.serviceType,
  required this.userLocation,

}) : super(key: key);

  
  


  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}
class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  List<WorkerModel> _nearbyWorkers = [];
  bool _isLoading = true;
  double _searchRadius = 5.0; // km
  String _sortBy = 'distance'; // distance, rating, price
  List<String> _selectedFilters = [];
  
  final List<String> _availableFilters = [
    'Disponible maintenant',
    'Évaluation 4+ étoiles',
    'Prix abordable',
    'Expérience 2+ ans',
    'Vérifié',
  ];

  @override
  void initState() {
    super.initState();
    _loadNearbyWorkers();
  }

  Future<void> _loadNearbyWorkers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final workers = await DatabaseService().getNearbyWorkers(
        widget.userLocation,
        widget.serviceType,
        _searchRadius,
      );

      // Appliquer les filtres
      List<WorkerModel> filteredWorkers = _applyFilters(workers);

      // Trier les résultats
      _sortWorkers(filteredWorkers);

      setState(() {
        _nearbyWorkers = filteredWorkers;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement travailleurs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<WorkerModel> _applyFilters(List<WorkerModel> workers) {
    return workers.where((worker) {
      for (String filter in _selectedFilters) {
        switch (filter) {
          case 'Disponible maintenant':
            if (!worker.isOnline) return false;
            break;
          case 'Évaluation 4+ étoiles':
            if (worker.rating < 4.0) return false;
            break;
          case 'Prix abordable':
            // Logique prix abordable (à définir selon critères)
            break;
          case 'Expérience 2+ ans':
            final experience = DateTime.now().difference(worker.createdAt).inDays / 365;
            if (experience < 2) return false;
            break;
          case 'Vérifié':
            if (!worker.isVerified) return false;
            break;
        }
      }
      return true;
    }).toList();
  }

  void _sortWorkers(List<WorkerModel> workers) {
    switch (_sortBy) {
      case 'distance':
        workers.sort((a, b) {
          double distanceA = Geolocator.distanceBetween(
            widget.userLocation.latitude,
            widget.userLocation.longitude,
            a.currentLocation!.latitude,
            a.currentLocation!.longitude,
          );
          double distanceB = Geolocator.distanceBetween(
            widget.userLocation.latitude,
            widget.userLocation.longitude,
            b.currentLocation!.latitude,
            b.currentLocation!.longitude,
          );
          return distanceA.compareTo(distanceB);
        });
        break;
      case 'rating':
        workers.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'price':
        workers.sort((a, b) {
          double priceA = a.priceList?[widget.serviceType] ?? 0.0;
          double priceB = b.priceList?[widget.serviceType] ?? 0.0;
          return priceA.compareTo(priceB);
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSecondaryColor,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        title: Text(
          widget.serviceType,
          style: TextStyle(
            color: kSecondaryColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: kSecondaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.map, color: kSecondaryColor),
            onPressed: () => _openMapView(),
          ),
        ],
      ),
      body: Column(
        children: [
          // En-tête avec filtres et tri
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Barre de recherche et rayon
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: kSecondaryColor,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: kPrimaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Rayon: ${_searchRadius.toInt()} km',
                              style: TextStyle(
                                color: kPrimaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(),
                            GestureDetector(
                              onTap: _showRadiusDialog,
                              child: Icon(Icons.tune, color: kPrimaryColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Filtres rapides
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tous', _selectedFilters.isEmpty),
                      ..._availableFilters.map((filter) => 
                        _buildFilterChip(filter, _selectedFilters.contains(filter))),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                // Options de tri
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSortButton('Distance', 'distance', Icons.location_on),
                    _buildSortButton('Note', 'rating', Icons.star),
                    _buildSortButton('Prix', 'price', Icons.attach_money),
                  ],
                ),
              ],
            ),
          ),
          
          // Liste des travailleurs
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: kPrimaryColor))
                : _nearbyWorkers.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: kPrimaryColor,
                        onRefresh: _loadNearbyWorkers,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _nearbyWorkers.length,
                          itemBuilder: (context, index) {
                            return _buildWorkerCard(_nearbyWorkers[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? kSecondaryColor : kPrimaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (label == 'Tous') {
              _selectedFilters.clear();
            } else {
              if (selected) {
                _selectedFilters.add(label);
              } else {
                _selectedFilters.remove(label);
              }
            }
          });
          _loadNearbyWorkers();
        },
        backgroundColor: kSecondaryColor,
        selectedColor: kAccentColor,
        checkmarkColor: kSecondaryColor,
        side: BorderSide(color: kSecondaryColor.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildSortButton(String label, String value, IconData icon) {
    bool isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
        });
        _loadNearbyWorkers();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kAccentColor : kSecondaryColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? kSecondaryColor : kSecondaryColor.withOpacity(0.8),
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? kSecondaryColor : kSecondaryColor.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerCard(WorkerModel worker) {
    double distance = Geolocator.distanceBetween(
      widget.userLocation.latitude,
      widget.userLocation.longitude,
      worker.currentLocation!.latitude,
      worker.currentLocation!.longitude,
    ) / 1000; // Convertir en km

    double price = worker.priceList?[widget.serviceType] ?? 0.0;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showWorkerDetails(worker),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Photo de profil
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: kPrimaryColor.withOpacity(0.3),
                        backgroundImage: worker.profileImageUrl != null
                            ? CachedNetworkImageProvider(worker.profileImageUrl!)
                            : null,
                        child: worker.profileImageUrl == null
                            ? Icon(Icons.person, color: kPrimaryColor, size: 30)
                            : null,
                      ),
                      if (worker.isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: kSuccessColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: kSecondaryColor, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 12),
                  
                  // Informations principales
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${worker.firstName} ${worker.lastName}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (worker.isVerified)
                              Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.verified,
                                  color: kPrimaryColor,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: kAccentColor, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '${worker.rating.toStringAsFixed(1)} (${worker.totalRatings})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(width: 12),
                            Icon(Icons.location_on, color: kErrorColor, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '${distance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Prix et statut
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (price > 0)
                        Text(
                          '${price.toInt()} DA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kAccentColor,
                          ),
                        ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: worker.isOnline ? kSuccessColor : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          worker.isOnline ? 'En ligne' : 'Hors ligne',
                          style: TextStyle(
                            color: kSecondaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              if (worker.bio != null && worker.bio!.isNotEmpty) ...[
                SizedBox(height: 12),
                Text(
                  worker.bio!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _contactWorker(worker),
                      icon: Icon(Icons.chat, size: 16),
                      label: Text('Contacter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        side: BorderSide(color: kPrimaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _bookWorker(worker),
                      icon: Icon(Icons.calendar_today, size: 16),
                      label: Text('Réserver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor,
                        foregroundColor: kSecondaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Aucun travailleur trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Essayez d\'augmenter le rayon de recherche\nou de modifier les filtres',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _searchRadius = 10.0;
                _selectedFilters.clear();
              });
              _loadNearbyWorkers();
            },
            icon: Icon(Icons.refresh),
            label: Text('Élargir la recherche'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: kSecondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRadiusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rayon de recherche'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_searchRadius.toInt()} km'),
              Slider(
                value: _searchRadius,
                min: 1.0,
                max: 50.0,
                divisions: 49,
                activeColor: kPrimaryColor,
                onChanged: (value) {
                  setStateDialog(() {
                    _searchRadius = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadNearbyWorkers();
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  void _openMapView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          
          userLocation: widget.userLocation,
          workers: _nearbyWorkers,
        ),
      ),
    );
  }
  void _showWorkerDetails(WorkerModel worker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: kSecondaryColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Contenu détaillé du travailleur
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête profil
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: worker.profileImageUrl != null
                              ? CachedNetworkImageProvider(worker.profileImageUrl!)
                              : null,
                          child: worker.profileImageUrl == null
                              ? Icon(Icons.person, size: 40, color: kPrimaryColor)
                              : null,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${worker.firstName} ${worker.lastName}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  RatingBar.builder(
                                    initialRating: worker.rating,
                                    minRating: 0,
                                    direction: Axis.horizontal,
                                    allowHalfRating: true,
                                    itemCount: 5,
                                    itemSize: 20,
                                    ignoreGestures: true,
                                    itemBuilder: (context, _) => Icon(
                                      Icons.star,
                                      color: kAccentColor,
                                    ),
                                    onRatingUpdate: (rating) {},
                                  ),
                                  SizedBox(width: 8),
                                  Text('(${worker.totalRatings} avis)'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Services et tarifs
                    Text(
                      'Services proposés',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: worker.services.map((service) => Chip(
                        label: Text(service),
                        backgroundColor: kPrimaryColor.withOpacity(0.1),
                        labelStyle: TextStyle(color: kPrimaryColor),
                      )).toList(),
                    ),
                    
                    if (worker.bio != null && worker.bio!.isNotEmpty) ...[
                      SizedBox(height: 20),
                      Text(
                        'À propos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        worker.bio!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                    
                    SizedBox(height: 32),
                    
                    // Boutons d'action
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _contactWorker(worker);
                            },
                            icon: Icon(Icons.chat),
                            label: Text('Contacter'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimaryColor,
                              side: BorderSide(color: kPrimaryColor),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _bookWorker(worker);
                            },
                            icon: Icon(Icons.calendar_today),
                            label: Text('Réserver'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccentColor,
                              foregroundColor: kSecondaryColor,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
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
  void _contactWorker(WorkerModel worker) {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;
    
    final chatId = '${currentUser.uid}_${worker.uid}';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
  chatId: chatId,
  otherUserId: worker.uid,
  otherUserName: '${worker.firstName} ${worker.lastName}',
  otherUserImageUrl: worker.profileImageUrl,
  selectedWorker: worker, // <-- إضافة العامل المحدد
  serviceType: widget.serviceType, // <-- إضافة نوع الخدمة
  isWorker: true, // <-- إضافة الحالة
),
      ),
    );
  }

  void _bookWorker(WorkerModel worker) {
    // Navigation vers l'écran de création de demande
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRequestScreen(
          
          selectedWorker: worker,
          userLocation: widget.userLocation,
        ),
      ),
    );
  }
}


// KHIDMETI APP - DÉVELOPPEMENT DE LA CLASSE : ChatDetailScreen

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImageUrl;
  final WorkerModel selectedWorker;
  final bool isWorker;
  final String? serviceType;


  // Replace line 8349 with:
  const ChatDetailScreen({
  Key? key,
  required this.chatId,
  required this.otherUserId,
  required this.otherUserName,
  required this.otherUserImageUrl,
  required this.selectedWorker,
  required this.serviceType,
  required this.isWorker,
}) : super(key: key);



  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  late String currentUserId;
  late String currentUserName;
  bool _isLoading = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  void _initializeUser() {
    final user = AuthService().currentUser;
    if (user != null) {
      currentUserId = user.uid;
      currentUserName = user.displayName ?? 'Utilisateur';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Envoyer un message texte
  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final chatMessage = ChatMessage(
      id: messageId,
      chatId: widget.chatId,
      senderId: currentUserId,
      senderName: currentUserName,
      message: message.trim(),
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    try {
      await DatabaseService().sendMessage(chatMessage);
      _messageController.clear();
      _scrollToBottom();
      
      // Envoyer notification push à l'autre utilisateur
      await NotificationService().sendNotificationToUser(
        widget.otherUserId,
        'Nouveau message de $currentUserName',
        message.trim(),
        {
          'type': 'chat',
          'chatId': widget.chatId,
          'senderId': currentUserId,
        },
      );
    } catch (e) {
      print('Erreur envoi message: $e');
      _showErrorSnackBar('Erreur lors de l\'envoi du message');
    }
  }

  // Envoyer une image
  Future<void> _sendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );

      if (image != null) {
        setState(() => _isLoading = true);

        // Upload de l'image
        final imageUrl = await StorageService().uploadChatImage(
          widget.chatId,
          File(image.path),
        );

        if (imageUrl != null) {
          final messageId = DateTime.now().millisecondsSinceEpoch.toString();
          final chatMessage = ChatMessage(
            id: messageId,
            chatId: widget.chatId,
            senderId: currentUserId,
            senderName: currentUserName,
            message: '📷 Image',
            type: MessageType.image,
            mediaUrl: imageUrl,
            timestamp: DateTime.now(),
          );

          await DatabaseService().sendMessage(chatMessage);
          _scrollToBottom();

          // Notification
          await NotificationService().sendNotificationToUser(
            widget.otherUserId,
            'Nouvelle image de $currentUserName',
            '📷 Image partagée',
            {
              'type': 'chat',
              'chatId': widget.chatId,
              'senderId': currentUserId,
            },
          );
        }
      }
    } catch (e) {
      print('Erreur envoi image: $e');
      _showErrorSnackBar('Erreur lors de l\'envoi de l\'image');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Prendre une photo avec la caméra
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
      );

      if (photo != null) {
        setState(() => _isLoading = true);

        final imageUrl = await StorageService().uploadChatImage(
          widget.chatId,
          File(photo.path),
        );

        if (imageUrl != null) {
          final messageId = DateTime.now().millisecondsSinceEpoch.toString();
          final chatMessage = ChatMessage(
            id: messageId,
            chatId: widget.chatId,
            senderId: currentUserId,
            senderName: currentUserName,
            message: '📸 Photo',
            type: MessageType.image,
            mediaUrl: imageUrl,
            timestamp: DateTime.now(),
          );

          await DatabaseService().sendMessage(chatMessage);
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Erreur prise photo: $e');
      _showErrorSnackBar('Erreur lors de la prise de photo');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Envoyer la localisation
  Future<void> _sendLocation() async {
    try {
      setState(() => _isLoading = true);

      final position = await LocationService().getCurrentPosition();
      if (position != null) {
        final address = await LocationService().getAddressFromCoordinates(
          LatLng(position.latitude, position.longitude),
        );

        final messageId = DateTime.now().millisecondsSinceEpoch.toString();
        final chatMessage = ChatMessage(
          id: messageId,
          chatId: widget.chatId,
          senderId: currentUserId,
          senderName: currentUserName,
          message: '📍 $address',
          type: MessageType.location,
          timestamp: DateTime.now(),
        );

        await DatabaseService().sendMessage(chatMessage);
        _scrollToBottom();
      } else {
        _showErrorSnackBar('Impossible d\'obtenir votre localisation');
      }
    } catch (e) {
      print('Erreur envoi localisation: $e');
      _showErrorSnackBar('Erreur lors de l\'envoi de la localisation');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kErrorColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Envoyer un fichier',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  onTap: () {
                    Navigator.pop(context);
                    _sendImage();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Caméra',
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.location_on,
                  label: 'Position',
                  onTap: () {
                    Navigator.pop(context);
                    _sendLocation();
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: kSecondaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: kPrimaryColor,
              backgroundImage: widget.otherUserImageUrl != null
                  ? CachedNetworkImageProvider(widget.otherUserImageUrl!)
                  : null,
              child: widget.otherUserImageUrl == null
                  ? Icon(Icons.person, color: kSecondaryColor)
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    widget.isWorker ? 'Travailleur' : 'Client',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.phone, color: kPrimaryColor),
            onPressed: () {
              // Fonctionnalité d'appel (à implémenter)
              _showErrorSnackBar('Fonctionnalité d\'appel bientôt disponible');
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: kPrimaryColor),
            onPressed: () {
              // Menu options (à implémenter)
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Liste des messages
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: DatabaseService().getChatMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: kPrimaryColor),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: kErrorColor),
                        SizedBox(height: 16),
                        Text(
                          'Erreur de chargement des messages',
                          style: TextStyle(color: kErrorColor),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Aucun message pour le moment',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Commencez la conversation !',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    
                    return ChatBubble(
                      message: message,
                      isMe: isMe,
                      showTimestamp: index == 0 || 
                          (index < messages.length - 1 && 
                           messages[index + 1].timestamp.difference(message.timestamp).inMinutes > 5),
                    );
                  },
                );
              },
            ),
          ),
          
          // Indicateur de chargement
          if (_isLoading)
            Container(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kPrimaryColor,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Envoi en cours...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          // Zone de saisie
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: kSecondaryColor,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Bouton pièce jointe
                  IconButton(
                    icon: Icon(Icons.attach_file, color: kPrimaryColor),
                    onPressed: _showAttachmentOptions,
                  ),
                  
                  // Champ de texte
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Tapez votre message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (text) {
                          setState(() {
                            _isTyping = text.trim().isNotEmpty;
                          });
                        },
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty) {
                            _sendMessage(text);
                          }
                        },
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 8),
                  
                  // Bouton d'envoi
                  Container(
                    decoration: BoxDecoration(
                      color: _isTyping ? kPrimaryColor : Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.send,
                        color: kSecondaryColor,
                        size: 20,
                      ),
                      onPressed: _isTyping
                          ? () => _sendMessage(_messageController.text)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// Widget pour les options de pièces jointes
class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentOption({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: kPrimaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: kSecondaryColor,
              size: 28,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}


// KHIDMETI APP - DÉVELOPPEMENT DE LA CLASSE : MapScreen

class MapScreen extends StatefulWidget {
  final String? selectedService;
  final LatLng? initialLocation;
  final LatLng? userLocation;
  final bool? selectLocation;
  final List<WorkerModel> workers;

  const MapScreen({
  Key? key,
  this.userLocation,
  this.selectLocation,
  this.selectedService,
  this.initialLocation,
  required this.workers,

}) : super(key: key);



  @override
  _MapScreenState createState() => _MapScreenState();
}
class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  List<WorkerModel> _nearbyWorkers = [];
  String? _selectedServiceFilter;
  double _searchRadius = 5.0; // km
  bool _isLoading = true;
  bool _showFilters = false;

  // Contrôleurs pour les filtres
  final TextEditingController _searchController = TextEditingController();
  RangeValues _ratingFilter = const RangeValues(0, 5);
  RangeValues _priceFilter = const RangeValues(0, 10000);

  @override
  void initState() {
    super.initState();
    _selectedServiceFilter = widget.selectedService;
    _initializeMap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);
    
    try {
      // Obtenir la position actuelle ou utiliser la position initiale
      if (widget.initialLocation != null) {
        _currentPosition = Position(
          latitude: widget.initialLocation!.latitude,
          longitude: widget.initialLocation!.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      } else {
        _currentPosition = await LocationService().getCurrentPosition();
      }

      if (_currentPosition != null) {
        await _loadNearbyWorkers();
        await _createMarkers();
      }
    } catch (e) {
      print('Erreur initialisation carte: $e');
      _showErrorSnackBar('Erreur lors du chargement de la carte');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNearbyWorkers() async {
    if (_currentPosition == null) return;

    try {
      final userLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      
      List<WorkerModel> workers = [];
      
      if (_selectedServiceFilter != null) {
        workers = await DatabaseService().getNearbyWorkers(
          userLocation,
          _selectedServiceFilter!,
          _searchRadius,
        );
      } else {
        // Charger tous les travailleurs proches, tous services confondus
        for (String service in kServices) {
          final serviceWorkers = await DatabaseService().getNearbyWorkers(
            userLocation,
            service,
            _searchRadius,
          );
          workers.addAll(serviceWorkers);
        }
        
        // Supprimer les doublons
        workers = workers.toSet().toList();
      }

      // Appliquer les filtres
      workers = _applyFilters(workers);

      setState(() {
        _nearbyWorkers = workers;
      });
    } catch (e) {
      print('Erreur chargement travailleurs: $e');
    }
  }

  List<WorkerModel> _applyFilters(List<WorkerModel> workers) {
    return workers.where((worker) {
      // Filtre par note
      if (worker.rating < _ratingFilter.start || worker.rating > _ratingFilter.end) {
        return false;
      }

      // Filtre par recherche textuelle
      if (_searchController.text.isNotEmpty) {
        final searchTerm = _searchController.text.toLowerCase();
        final fullName = '${worker.firstName} ${worker.lastName}'.toLowerCase();
        final services = worker.services.join(' ').toLowerCase();
        
        if (!fullName.contains(searchTerm) && !services.contains(searchTerm)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _createMarkers() async {
    final markers = <Marker>{};

    // Marqueur de position actuelle
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_position'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Ma position',
            snippet: 'Vous êtes ici',
          ),
        ),
      );
    }

    // Marqueurs des travailleurs
    for (int i = 0; i < _nearbyWorkers.length; i++) {
      final worker = _nearbyWorkers[i];
      if (worker.currentLocation != null) {
        markers.add(
          Marker(
            markerId: MarkerId('worker_${worker.uid}'),
            position: worker.currentLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerColorForService(worker.services.first),
            ),
            infoWindow: InfoWindow(
              title: '${worker.firstName} ${worker.lastName}',
              snippet: '${worker.services.join(', ')} - ${worker.rating.toStringAsFixed(1)}⭐',
            ),
            onTap: () => _showWorkerDetails(worker),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  double _getMarkerColorForService(String service) {
    switch (service) {
      case 'Plomberie':
        return BitmapDescriptor.hueRed;
      case 'Électricité':
        return BitmapDescriptor.hueYellow;
      case 'Nettoyage':
        return BitmapDescriptor.hueGreen;
      case 'Livraison':
        return BitmapDescriptor.hueOrange;
      case 'Peinture':
        return BitmapDescriptor.hueMagenta;
      case 'Réparation électroménager':
        return BitmapDescriptor.hueViolet;
      case 'Maçonnerie':
        return BitmapDescriptor.hueRose;
      case 'Climatisation':
        return BitmapDescriptor.hueCyan;
      case 'Baby-sitting':
        return BitmapDescriptor.hueAzure;
      case 'Cours particuliers':
        return BitmapDescriptor.hueBlue;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  void _showWorkerDetails(WorkerModel worker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: kSecondaryColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle de glissement
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Photo et nom
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: kPrimaryColor,
                    backgroundImage: worker.profileImageUrl != null
                        ? CachedNetworkImageProvider(worker.profileImageUrl!)
                        : null,
                    child: worker.profileImageUrl == null
                        ? Text(
                            '${worker.firstName[0]}${worker.lastName[0]}',
                            style: const TextStyle(
                              color: kSecondaryColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${worker.firstName} ${worker.lastName}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            RatingBarIndicator(
                              rating: worker.rating,
                              itemBuilder: (context, index) => const Icon(
                                Icons.star,
                                color: Colors.amber,
                              ),
                              itemCount: 5,
                              itemSize: 16.0,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${worker.rating.toStringAsFixed(1)} (${worker.totalRatings})',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: worker.isOnline ? kSuccessColor : Colors.grey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      worker.isOnline ? 'En ligne' : 'Hors ligne',
                      style: const TextStyle(
                        color: kSecondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Services
              const Text(
                'Services proposés:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: worker.services.map((service) => Chip(
                  label: Text(
                    service,
                    style: const TextStyle(
                      color: kSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: kPrimaryColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // Bio
              if (worker.bio != null && worker.bio!.isNotEmpty) ...[
                const Text(
                  'À propos:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  worker.bio!,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Distance
              if (worker.currentLocation != null && _currentPosition != null) ...[
                Row(
                  children: [
                    const Icon(Icons.location_on, color: kAccentColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${(LocationService().calculateDistance(
                        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        worker.currentLocation!,
                      ) / 1000).toStringAsFixed(1)} km',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              const Spacer(),
              
              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _contactWorker(worker);
                      },
                      icon: const Icon(Icons.chat, color: kSecondaryColor),
                      label: const Text(
                        'Contacter',
                        style: TextStyle(color: kSecondaryColor),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _createRequest(worker);
                      },
                      icon: const Icon(Icons.work, color: kSecondaryColor),
                      label: const Text(
                        'Demander',
                        style: TextStyle(color: kSecondaryColor),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _contactWorker(WorkerModel worker) {
    // Navigation vers le chat
    final chatId = _generateChatId(AuthService().currentUser!.uid, worker.uid);
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'chatId': chatId,
        'workerId': worker.uid,
        'workerName': '${worker.firstName} ${worker.lastName}',
      },
    );
  }

  void _createRequest(WorkerModel worker) {
    // Navigation vers la création de demande avec travailleur pré-sélectionné
    Navigator.pushNamed(
      context,
      '/create-request',
      arguments: {
        'selectedWorker': worker,
        'serviceType': _selectedServiceFilter,
      },
    );
  }

  String _generateChatId(String userId, String workerId) {
    final ids = [userId, workerId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kErrorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: kSecondaryColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                const Text(
                  'Filtres de recherche',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Service filter
                const Text(
                  'Service:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedServiceFilter,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  hint: const Text('Tous les services'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tous les services'),
                    ),
                    ...kServices.map((service) => DropdownMenuItem(
                      value: service,
                      child: Text(service),
                    )).toList(),
                  ],
                  onChanged: (value) {
                    setModalState(() {
                      _selectedServiceFilter = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                
                // Rating filter
                const Text(
                  'Note minimale:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                RangeSlider(
                  values: _ratingFilter,
                  min: 0,
                  max: 5,
                  divisions: 10,
                  activeColor: kPrimaryColor,
                  labels: RangeLabels(
                    _ratingFilter.start.toStringAsFixed(1),
                    _ratingFilter.end.toStringAsFixed(1),
                  ),
                  onChanged: (values) {
                    setModalState(() {
                      _ratingFilter = values;
                    });
                  },
                ),
                const SizedBox(height: 20),
                
                // Search radius
                const Text(
                  'Rayon de recherche:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _searchRadius,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  activeColor: kPrimaryColor,
                  label: '${_searchRadius.toInt()} km',
                  onChanged: (value) {
                    setModalState(() {
                      _searchRadius = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                
                // Search text
                const Text(
                  'Recherche:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Nom ou service...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                
                const Spacer(),
                
                // Apply filters button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _applyFiltersAndRefresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Appliquer les filtres',
                      style: TextStyle(
                        color: kSecondaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                
                // Reset filters button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      setModalState(() {
                        _selectedServiceFilter = null;
                        _ratingFilter = const RangeValues(0, 5);
                        _searchRadius = 5.0;
                        _searchController.clear();
                      });
                    },
                    child: const Text(
                      'Réinitialiser',
                      style: TextStyle(
                        color: kAccentColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyFiltersAndRefresh() async {
    setState(() => _isLoading = true);
    await _loadNearbyWorkers();
    await _createMarkers();
    setState(() => _isLoading = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSecondaryColor,
      appBar: AppBar(
        title: const Text(
          'Travailleurs proches',
          style: TextStyle(
            color: kSecondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kSecondaryColor),
        actions: [
          IconButton(
            onPressed: _showFiltersBottomSheet,
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_selectedServiceFilter != null || 
                    _ratingFilter.start > 0 || 
                    _searchController.text.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: kAccentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _initializeMap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: kPrimaryColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chargement de la carte...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _currentPosition == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Impossible d\'obtenir votre position',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vérifiez les permissions de localisation',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                      },
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15.0,
                      ),
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      mapToolbarEnabled: false,
                      onTap: (LatLng position) {
                        // Fermer les info windows
                        setState(() {});
                      },
                    ),
                    
                    // Nombre de travailleurs trouvés
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: kSecondaryColor,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.people,
                              color: kPrimaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_nearbyWorkers.length} travailleur(s) trouvé(s)',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}


// KHIDMETI APP - DÉVELOPPEMENT DE LA CLASSE : SubscriptionScreen

class SubscriptionScreen extends StatefulWidget {
  final WorkerModel worker;
  const SubscriptionScreen({Key? key, required this.worker}) : super(key: key);
  

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  String _selectedPlan = 'monthly'; // 'monthly' ou 'yearly'
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Abonnement Travailleur',
          style: TextStyle(
            color: kSecondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: kSecondaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: _buildContent(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          SizedBox(height: 30),
          _buildCurrentStatusCard(),
          SizedBox(height: 30),
          _buildSubscriptionPlans(),
          SizedBox(height: 30),
          _buildFeaturesSection(),
          SizedBox(height: 30),
          _buildSubscribeButton(),
          SizedBox(height: 20),
          _buildTermsAndConditions(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor.withOpacity(0.8), kAccentColor.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: kSecondaryColor,
                child: Icon(
                  Icons.work,
                  color: kPrimaryColor,
                  size: 30,
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenue ${widget.worker?.firstName ?? ''}!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kSecondaryColor,
                      ),
                    ),
                    Text(
                      'Développez votre activité avec Khidmeti',
                      style: TextStyle(
                        fontSize: 14,
                        color: kSecondaryColor.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Text(
            'Accédez à plus de clients et gérez votre business efficacement avec notre plateforme.',
            style: TextStyle(
              fontSize: 16,
              color: kSecondaryColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    final isSubscribed = widget.worker?.isSubscribed ?? false;
    final endDate = widget.worker?.subscriptionEndDate;
    final daysRemaining = endDate != null 
        ? endDate.difference(DateTime.now()).inDays 
        : 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSecondaryColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isSubscribed ? kSuccessColor : kErrorColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSubscribed ? Icons.check_circle : Icons.cancel,
                color: isSubscribed ? kSuccessColor : kErrorColor,
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Statut d\'abonnement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          if (isSubscribed) ...[
            Text(
              'Abonnement actif',
              style: TextStyle(
                fontSize: 16,
                color: kSuccessColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Text(
              endDate != null 
                  ? 'Expire le ${DateFormat('dd/MM/yyyy').format(endDate)} ($daysRemaining jours restants)'
                  : 'Aucune date d\'expiration',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ] else ...[
            Text(
              'Aucun abonnement actif',
              style: TextStyle(
                fontSize: 16,
                color: kErrorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Abonnez-vous pour recevoir des demandes de clients',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choisissez votre plan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildPlanCard(
                title: 'Mensuel',
                price: '1000 DA',
                period: '/mois',
                value: 'monthly',
                isPopular: false,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: _buildPlanCard(
                title: 'Annuel',
                price: '10000 DA',
                period: '/an',
                value: 'yearly',
                isPopular: true,
                savings: 'Économisez 2000 DA',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required String value,
    bool isPopular = false,
    String? savings,
  }) {
    final isSelected = _selectedPlan == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = value;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withOpacity(0.1) : kSecondaryColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? kPrimaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? kPrimaryColor.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPopular) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kAccentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'POPULAIRE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: kSecondaryColor,
                  ),
                ),
              ),
              SizedBox(height: 10),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
                Text(
                  period,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (savings != null) ...[
              SizedBox(height: 5),
              Text(
                savings,
                style: TextStyle(
                  fontSize: 12,
                  color: kSuccessColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            SizedBox(height: 15),
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? kPrimaryColor : Colors.grey[400],
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Sélectionner',
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? kPrimaryColor : Colors.grey[600],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final features = [
      {'icon': Icons.notifications_active, 'title': 'Notifications de demandes', 'desc': 'Recevez instantanément les nouvelles demandes'},
      {'icon': Icons.location_on, 'title': 'Géolocalisation', 'desc': 'Apparaissez dans les recherches de proximité'},
      {'icon': Icons.chat, 'title': 'Chat en temps réel', 'desc': 'Communiquez directement avec vos clients'},
      {'icon': Icons.star, 'title': 'Système d\'évaluation', 'desc': 'Construisez votre réputation sur la plateforme'},
      {'icon': Icons.history, 'title': 'Historique des services', 'desc': 'Suivez tous vos services et revenus'},
      {'icon': Icons.support_agent, 'title': 'Support prioritaire', 'desc': 'Assistance technique dédiée'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fonctionnalités incluses',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kSecondaryColor,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: features.map((feature) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        color: kPrimaryColor,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature['title'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            feature['desc'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: kSuccessColor,
                      size: 20,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscribeButton() {
    final selectedPlanText = _selectedPlan == 'monthly' ? 'Mensuel (1000 DA)' : 'Annuel (10000 DA)';
    
    return Container(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubscription,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: kSecondaryColor,
          elevation: 5,
          shadowColor: kPrimaryColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(kSecondaryColor),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Traitement...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'S\'abonner - $selectedPlanText',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Column(
      children: [
        Text(
          'En vous abonnant, vous acceptez nos conditions d\'utilisation et notre politique de confidentialité.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                _showTermsDialog();
              },
              child: Text(
                'Conditions d\'utilisation',
                style: TextStyle(
                  fontSize: 12,
                  color: kPrimaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(' | ', style: TextStyle(color: Colors.grey[400])),
            TextButton(
              onPressed: () {
                _showPrivacyDialog();
              },
              child: Text(
                'Politique de confidentialité',
                style: TextStyle(
                  fontSize: 12,
                  color: kPrimaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleSubscription() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Vérifier si l'utilisateur a déjà un abonnement actif
      if (widget.worker?.subscriptionEndDate?.isAfter(DateTime.now()) ?? false
) {
        
        _showAlreadySubscribedDialog();
        return;
      }

      // Calculer la date d'expiration selon le plan choisi
      DateTime endDate;
      double amount;
      
      if (_selectedPlan == 'monthly') {
        endDate = DateTime.now().add(Duration(days: 30));
        amount = 1000.0;
      } else {
        endDate = DateTime.now().add(Duration(days: 365));
        amount = 10000.0;
      }

      // Naviguer vers l'écran de paiement
      final paymentResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            amount: amount,
            plan: _selectedPlan,
            worker: widget.worker,
            subscriptionEndDate: endDate,
          ),
        ),
      );

      if (paymentResult == true) {
        // Paiement réussi, mettre à jour le statut du travailleur
        await _updateWorkerSubscription(endDate);
        _showSuccessDialog();
      }

    } catch (e) {
      print('Erreur lors de l\'abonnement: $e');
      _showErrorDialog('Une erreur est survenue lors du traitement de votre abonnement.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateWorkerSubscription(DateTime endDate) async {
    try {
      if (widget.worker != null) {
  await _firestore.collection('workers').doc(widget.worker!.uid).update({
        'isSubscribed': true,
        'subscriptionEndDate': Timestamp.fromDate(endDate),
      });}

      // Mettre à jour l'objet worker local
      widget.worker?.copyWith(
        isSubscribed: true,
        subscriptionEndDate: endDate,
      );

    } catch (e) {
      print('Erreur mise à jour abonnement: $e');
      throw e;
    }
  }

  void _showAlreadySubscribedDialog() {
  final subscriptionDate = widget.worker?.subscriptionEndDate;
  final expirationText = subscriptionDate != null
      ? DateFormat('dd/MM/yyyy').format(subscriptionDate)
      : 'inconnue';

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Abonnement actif'),
      content: Text(
          'Vous avez déjà un abonnement actif. Votre abonnement actuel expire le $expirationText.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK', style: TextStyle(color: kPrimaryColor)),
        ),
      ],
    ),
  );
}

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: kSuccessColor),
            SizedBox(width: 10),
            Text('Abonnement activé'),
          ],
        ),
        content: Text('Félicitations! Votre abonnement a été activé avec succès. Vous pouvez maintenant recevoir des demandes de clients.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Fermer le dialog
              Navigator.pop(context, true); // Retourner à l'écran précédent
            },
            child: Text('Continuer', style: TextStyle(color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: kErrorColor),
            SizedBox(width: 10),
            Text('Erreur'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Conditions d\'utilisation'),
        content: SingleChildScrollView(
          child: Text(
            '''Conditions d'utilisation de Khidmeti

1. ACCEPTATION DES CONDITIONS
En utilisant l'application Khidmeti, vous acceptez d'être lié par ces conditions d'utilisation.

2. DESCRIPTION DU SERVICE
Khidmeti est une plateforme de mise en relation entre clients et travailleurs qualifiés.

3. ABONNEMENT TRAVAILLEUR
- L'abonnement donne accès aux demandes de clients
- Le paiement est mensuel (1000 DA) ou annuel (10000 DA)
- L'abonnement se renouvelle automatiquement

4. OBLIGATIONS DU TRAVAILLEUR
- Fournir des informations exactes
- Respecter les rendez-vous pris
- Maintenir un service de qualité

5. RÉSILIATION
L'abonnement peut être résilié à tout moment depuis l'application.

6. LIMITATION DE RESPONSABILITÉ
Khidmeti n'est pas responsable des litiges entre clients et travailleurs.

Dernière mise à jour: Janvier 2025''',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Politique de confidentialité'),
        content: SingleChildScrollView(
          child: Text(
            '''Politique de confidentialité de Khidmeti

1. COLLECTE DES DONNÉES
Nous collectons les informations nécessaires au fonctionnement du service:
- Informations d'identification
- Localisation (pour les travailleurs)
- Données d'utilisation

2. UTILISATION DES DONNÉES
Vos données sont utilisées pour:
- Fournir le service de mise en relation
- Améliorer l'application
- Communiquer avec vous

3. PARTAGE DES DONNÉES
Nous ne vendons pas vos données personnelles à des tiers.

4. SÉCURITÉ
Nous mettons en place des mesures de sécurité pour protéger vos données.

5. VOS DROITS
Vous pouvez demander l'accès, la rectification ou la suppression de vos données.

6. CONTACT
Pour toute question: support@khidmeti.dz

Dernière mise à jour: Janvier 2025''',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }
}

// KHIDMETI APP - DÉVELOPPEMENT DE LA CLASSE : PaymentScreen

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String plan;
  final WorkerModel worker;
  final DateTime subscriptionEndDate;
  
  const PaymentScreen({
  Key? key,
  required this.worker,
  required this.amount,
  required this.plan,
  required this.subscriptionEndDate,

}) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with TickerProviderStateMixin {
  String _selectedPaymentMethod = 'baridimob'; // 'baridimob' ou 'card'
  bool _isProcessing = false;
  bool _paymentCompleted = false;
  
  
  // Contrôleurs pour les champs de carte
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  
  // Contrôleurs pour BaridiMob
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  
  // Animations
  late AnimationController _slideController;
  late AnimationController _bounceController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _bounceAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Configuration des animations
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _bounceAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
    
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _bounceController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Paiement',
          style: TextStyle(
            color: kSecondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: kSecondaryColor),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
      ),
      body: _paymentCompleted ? _buildSuccessView() : _buildPaymentView(),
    );
  }

  Widget _buildPaymentView() {
    return SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderSummary(),
            SizedBox(height: 25),
            _buildPaymentMethodSelection(),
            SizedBox(height: 25),
            _buildPaymentForm(),
            SizedBox(height: 30),
            _buildPayButton(),
            SizedBox(height: 20),
            _buildSecurityInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSecondaryColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: kPrimaryColor, size: 24),
              SizedBox(width: 10),
              Text(
                'Récapitulatif de commande',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildSummaryRow('Plan sélectionné', widget.plan == 'monthly' ? 'Abonnement mensuel' : 'Abonnement annuel'),
          _buildSummaryRow('Durée', widget.plan == 'monthly' ? '30 jours' : '365 jours'),
          _buildSummaryRow('Date d\'expiration', DateFormat('dd/MM/yyyy').format(widget.subscriptionEndDate)),
          if (widget.plan == 'yearly') 
            _buildSummaryRow('Économies', '2000 DA', color: kSuccessColor),
          Divider(height: 25, thickness: 1),
          _buildSummaryRow('Total à payer', '${widget.amount.toInt()} DA', 
              isTotal: true, color: kPrimaryColor),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: color ?? (isTotal ? kPrimaryColor : Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Méthode de paiement',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildPaymentMethodCard(
                'baridimob',
                'BaridiMob',
                Icons.phone_android,
                'Paiement mobile sécurisé',
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: _buildPaymentMethodCard(
                'card',
                'Carte bancaire',
                Icons.credit_card,
                'Visa, MasterCard',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(String value, String title, IconData icon, String subtitle) {
    final isSelected = _selectedPaymentMethod == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withOpacity(0.1) : kSecondaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? kPrimaryColor.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? kPrimaryColor : Colors.grey[600],
            ),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? kPrimaryColor : Colors.grey[800],
              ),
            ),
            SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? kPrimaryColor : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSecondaryColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: _selectedPaymentMethod == 'baridimob' 
          ? _buildBaridiMobForm() 
          : _buildCardForm(),
    );
  }

  Widget _buildBaridiMobForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.phone_android, color: kPrimaryColor),
            SizedBox(width: 10),
            Text(
              'Paiement BaridiMob',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        _buildTextField(
          controller: _phoneController,
          label: 'Numéro de téléphone',
          hint: '0X XX XX XX XX',
          prefixIcon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: _validatePhone,
        ),
        SizedBox(height: 15),
        _buildTextField(
          controller: _pinController,
          label: 'Code PIN BaridiMob',
          hint: 'Entrez votre code PIN',
          prefixIcon: Icons.lock,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          validator: _validatePin,
        ),
        SizedBox(height: 15),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue[600], size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Un SMS de confirmation sera envoyé à votre numéro',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.credit_card, color: kPrimaryColor),
            SizedBox(width: 10),
            Text(
              'Informations de carte',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        _buildTextField(
          controller: _cardHolderController,
          label: 'Nom du titulaire',
          hint: 'Nom sur la carte',
          prefixIcon: Icons.person,
          validator: _validateCardHolder,
        ),
        SizedBox(height: 15),
        _buildTextField(
          controller: _cardNumberController,
          label: 'Numéro de carte',
          hint: '1234 5678 9012 3456',
          prefixIcon: Icons.credit_card,
          keyboardType: TextInputType.number,
          validator: _validateCardNumber,
          onChanged: _formatCardNumber,
        ),
        SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTextField(
                controller: _expiryController,
                label: 'Date d\'expiration',
                hint: 'MM/AA',
                prefixIcon: Icons.calendar_today,
                keyboardType: TextInputType.number,
                validator: _validateExpiry,
                onChanged: _formatExpiry,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: _buildTextField(
                controller: _cvvController,
                label: 'CVV',
                hint: '123',
                prefixIcon: Icons.security,
                keyboardType: TextInputType.number,
                maxLength: 3,
                obscureText: true,
                validator: _validateCVV,
              ),
            ),
          ],
        ),
        SizedBox(height: 15),
        Row(
          children: [
            Icon(Icons.security, color: kSuccessColor, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vos informations sont sécurisées et cryptées',
                style: TextStyle(
                  fontSize: 12,
                  color: kSuccessColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    int? maxLength,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: kPrimaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: kPrimaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        counterText: '',
        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
    );
  }
  Widget _buildPayButton() {
    return Container(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: kSecondaryColor,
          elevation: 5,
          shadowColor: kPrimaryColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isProcessing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(kSecondaryColor),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Traitement en cours...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Payer ${widget.amount.toInt()} DA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.shield, color: kSuccessColor, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Paiement 100% sécurisé',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kSuccessColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Vos informations de paiement sont protégées par un cryptage SSL 256 bits et ne sont jamais stockées sur nos serveurs.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return ScaleTransition(
      scale: _bounceAnimation,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: kSuccessColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kSuccessColor.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check,
                  color: kSecondaryColor,
                  size: 60,
                ),
              ),
              SizedBox(height: 30),
              Text(
                'Paiement réussi!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 15),
              Text(
                'Votre abonnement a été activé avec succès.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Vous pouvez maintenant recevoir des demandes de clients.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              SizedBox(height: 40),
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true); // Retourner avec succès
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: kSecondaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Continuer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  // Validation des champs
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Numéro requis';
    if (!RegExp(r'^0[5-7][0-9]{8}$').hasMatch(value.replaceAll(' ', ''))) {
      return 'Numéro invalide';
    }
    return null;
  }

  String? _validatePin(String? value) {
    if (value == null || value.isEmpty) return 'PIN requis';
    if (value.length != 4) return 'PIN doit contenir 4 chiffres';
    return null;
  }

  String? _validateCardHolder(String? value) {
    if (value == null || value.isEmpty) return 'Nom requis';
    return null;
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) return 'Numéro requis';
    final cleaned = value.replaceAll(' ', '');
    if (cleaned.length != 16) return 'Numéro invalide';
    return null;
  }

  String? _validateExpiry(String? value) {
    if (value == null || value.isEmpty) return 'Date requise';
    if (!RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').hasMatch(value)) {
      return 'Format: MM/AA';
    }
    return null;
  }

  String? _validateCVV(String? value) {
    if (value == null || value.isEmpty) return 'CVV requis';
    if (value.length != 3) return 'CVV invalide';
    return null;
  }

  // Formatage des champs
  void _formatCardNumber(String value) {
    final formatted = value.replaceAll(' ', '').replaceAllMapped(
      RegExp(r'.{4}'),
      (match) => '${match.group(0)} ',
    ).trim();
    if (formatted != value) {
      _cardNumberController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _formatExpiry(String value) {
    if (value.length == 2 && !value.contains('/')) {
      _expiryController.value = TextEditingValue(
        text: '$value/',
        selection: TextSelection.collapsed(offset: 3),
      );
    }
  }

  // Traitement du paiement (simulation)
  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Validation des champs
      bool isValid = false;
      
      if (_selectedPaymentMethod == 'baridimob') {
        isValid = _validateBaridiMobFields();
      } else {
        isValid = _validateCardFields();
      }

      if (!isValid) {
        _showErrorDialog('Veuillez vérifier les informations saisies.');
        return;
      }

      // Simulation du traitement de paiement
      await Future.delayed(Duration(seconds: 3));
      
      // Simuler succès (90% de chance de succès pour la démo)
      final random = DateTime.now().millisecondsSinceEpoch % 10;
      if (random < 9) {
        // Paiement réussi
        await _updateSubscription();
        setState(() {
          _paymentCompleted = true;
        });
        _bounceController.forward();
      } else {
        // Échec du paiement (pour simulation)
        _showErrorDialog('Le paiement a échoué. Veuillez réessayer.');
      }

    } catch (e) {
      print('Erreur de paiement: $e');
      _showErrorDialog('Une erreur technique est survenue.');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  bool _validateBaridiMobFields() {
    return _validatePhone(_phoneController.text) == null &&
           _validatePin(_pinController.text) == null;
  }

  bool _validateCardFields() {
    return _validateCardHolder(_cardHolderController.text) == null &&
           _validateCardNumber(_cardNumberController.text) == null &&
           _validateExpiry(_expiryController.text) == null &&
           _validateCVV(_cvvController.text) == null;
  }

  Future<void> _updateSubscription() async {
    try {
      // Mettre à jour le statut d'abonnement dans Firestore
      await _firestore.collection('workers').doc(widget.worker.uid).update({
        'isSubscribed': true,
        'subscriptionEndDate': Timestamp.fromDate(widget.subscriptionEndDate),
        'lastPaymentDate': Timestamp.now(),
        'lastPaymentAmount': widget.amount,
        'paymentMethod': _selectedPaymentMethod,
      });

      // Enregistrer la transaction de paiement
      await _firestore.collection('payments').add({
        'workerId': widget.worker.uid,
        'amount': widget.amount,
        'plan': widget.plan,
        'paymentMethod': _selectedPaymentMethod,
        'timestamp': Timestamp.now(),
        'subscriptionEndDate': Timestamp.fromDate(widget.subscriptionEndDate),
        'status': 'completed',
      });

      // Envoyer une notification de confirmation
      await NotificationService().showLocalNotification(
        'Abonnement activé',
        'Votre abonnement ${widget.plan == 'monthly' ? 'mensuel' : 'annuel'} a été activé avec succès!',
      );

    } catch (e) {
      print('Erreur mise à jour abonnement: $e');
      throw e;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: kErrorColor),
            SizedBox(width: 10),
            Text('Erreur de paiement'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }
}


// ===== WIDGETS UTILITAIRES =====

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final bool showBackButton;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 0,
    this.showBackButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: foregroundColor ?? Colors.white,
        ),
      ),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? kPrimaryColor,
      foregroundColor: foregroundColor ?? Colors.white,
      elevation: elevation,
      automaticallyImplyLeading: showBackButton,
      leading: leading,
      actions: actions,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class ServiceCard extends StatelessWidget {
  final String serviceName;
  final String? iconUrl;
  final Color color;
  final VoidCallback? onTap;
  final bool isSelected;
  final double? rating;

  const ServiceCard({
    Key? key,
    required this.serviceName,
    this.iconUrl,
    this.color = kPrimaryColor,
    this.onTap,
    this.isSelected = false,
    this.rating,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.8) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône du service
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  _getServiceIcon(serviceName),
                  size: 30,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              
              // Nom du service
              Text(
                serviceName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Rating si disponible
              if (rating != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: kAccentColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      rating!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceName) {
    switch (serviceName.toLowerCase()) {
      case 'plomberie':
        return Icons.plumbing;
      case 'électricité':
        return Icons.electrical_services;
      case 'nettoyage':
        return Icons.cleaning_services;
      case 'livraison':
        return Icons.delivery_dining;
      case 'peinture':
        return Icons.format_paint;
      case 'réparation électroménager':
        return Icons.home_repair_service;
      case 'maçonnerie':
        return Icons.construction;
      case 'climatisation':
        return Icons.ac_unit;
      case 'baby-sitting':
        return Icons.child_care;
      case 'cours particuliers':
        return Icons.school;
      default:
        return Icons.work;
    }
  }
}

class WorkerCard extends StatelessWidget {
  final WorkerModel worker;
  final double? distance;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final bool showActions;

  const WorkerCard({
    Key? key,
    required this.worker,
    this.distance,
    this.onTap,
    this.onCall,
    this.onMessage,
    this.showActions = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Photo de profil
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: kPrimaryColor.withOpacity(0.1),
                        backgroundImage: worker.profileImageUrl != null
                            ? CachedNetworkImageProvider(worker.profileImageUrl!)
                            : null,
                        child: worker.profileImageUrl == null
                            ? Icon(
                                Icons.person,
                                size: 35,
                                color: kPrimaryColor,
                              )
                            : null,
                      ),
                      // Indicateur en ligne
                      if (worker.isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: kSuccessColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  // Informations du travailleur
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${worker.firstName} ${worker.lastName}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (worker.isVerified)
                              Icon(
                                Icons.verified,
                                color: kSuccessColor,
                                size: 20,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // Services
                        Text(
                          worker.services.take(2).join(', ') +
                              (worker.services.length > 2 ? '...' : ''),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        
                        // Rating et distance
                        Row(
                          children: [
                            // Rating
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  color: kAccentColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  worker.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  ' (${worker.totalRatings})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            
                            const Spacer(),
                            
                            // Distance
                            if (distance != null) ...[
                              Icon(
                                Icons.location_on,
                                color: kPrimaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${distance!.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: kPrimaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Bio si disponible
              if (worker.bio != null && worker.bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  worker.bio!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              // Actions
              if (showActions) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Statut
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: worker.isOnline 
                            ? kSuccessColor.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        worker.isOnline ? 'En ligne' : 'Hors ligne',
                        style: TextStyle(
                          fontSize: 12,
                          color: worker.isOnline ? kSuccessColor : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Boutons d'action
                    if (onCall != null)
                      IconButton(
                        onPressed: onCall,
                        icon: Icon(
                          Icons.phone,
                          color: kSuccessColor,
                        ),
                        tooltip: 'Appeler',
                      ),
                    
                    if (onMessage != null)
                      IconButton(
                        onPressed: onMessage,
                        icon: Icon(
                          Icons.message,
                          color: kPrimaryColor,
                        ),
                        tooltip: 'Message',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
class RequestCard extends StatelessWidget {
  final RequestModel request;
  final UserModel? user;
  final WorkerModel? worker;
  final VoidCallback? onTap;
  final VoidCallback? onAccept; // دالة لقبول الطلب
  final VoidCallback? onReject; // دالة لرفض الطلب
  final bool showUser;
  final bool showWorker;
  final bool isWorker; // يحدد ما إذا كان المستخدم عاملاً
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;
  final VoidCallback? onRate; // إضافة onRate
  final bool isHistory;

  const RequestCard({
    Key? key,
    required this.request,
    this.user,
    this.worker,
    this.onTap,
    this.onAccept,
    this.onReject,
    this.showUser = false,
    this.showWorker = false,
    required this.isWorker,
    this.onComplete,
    this.onCancel,
    required this.isHistory,
    this.onRate, 

  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getStatusColor().withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header مع عنوان الطلب وحالته
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // نوع الخدمة والأولوية (عاجل)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      request.serviceType,
                      style: TextStyle(
                        fontSize: 12,
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (request.isUrgent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kErrorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.priority_high,
                            size: 14,
                            color: kErrorColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Urgent',
                            style: TextStyle(
                              fontSize: 12,
                              color: kErrorColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // وصف الطلب
              Text(
                request.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // معلومات المستخدم إذا كان يجب عرضها
              if (showUser && user != null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: kPrimaryColor.withOpacity(0.1),
                      backgroundImage: user!.profileImageUrl != null
                          ? CachedNetworkImageProvider(user!.profileImageUrl!)
                          : null,
                      child: user!.profileImageUrl == null
                          ? Icon(
                              Icons.person,
                              size: 18,
                              color: kPrimaryColor,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${user!.firstName} ${user!.lastName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // معلومات العامل إذا كان يجب عرضها
              if (showWorker && worker != null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: kPrimaryColor.withOpacity(0.1),
                      backgroundImage: worker!.profileImageUrl != null
                          ? CachedNetworkImageProvider(worker!.profileImageUrl!)
                          : null,
                      child: worker!.profileImageUrl == null
                          ? Icon(
                              Icons.person,
                              size: 18,
                              color: kPrimaryColor,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${worker!.firstName} ${worker!.lastName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (worker!.rating > 0) ...[
                      Icon(
                        Icons.star,
                        color: kAccentColor,
                        size: 16,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        worker!.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Footer مع العنوان وتاريخ الإنشاء
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            request.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(request.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),

              // الميزانية إذا كانت متوفرة
              if (request.budget != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 16,
                      color: kSuccessColor,
                    ),
                    Text(
                      'Budget: ${request.budget!.toStringAsFixed(0)} DA',
                      style: TextStyle(
                        fontSize: 14,
                        color: kSuccessColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              // التقييم إذا كان الطلب مكتملاً
              if (request.status == RequestStatus.completed && request.rating != null) ...[
                const SizedBox(height: 8),
                RatingWidget(
                  rating: request.rating!,
                  size: 16,
                  showText: true,
                ),
              ],

              // أزرار قبول/رفض للعامل إذا كان الطلب معلقاً
              if (isWorker && request.status == RequestStatus.pending) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CustomButton(
                      text: 'رفض',
                      onPressed: onReject,
                      backgroundColor: kErrorColor,
                      width: 120,
                      height: 40,
                      borderRadius: 10,
                      icon: Icons.close,
                    ),
                    const SizedBox(width: 8),
                    CustomButton(
                      text: 'قبول',
                      onPressed: onAccept,
                      backgroundColor: kSuccessColor,
                      width: 120,
                      height: 40,
                      borderRadius: 10,
                      icon: Icons.check,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// إرجاع لون الحالة بناءً على حالة الطلب
  Color _getStatusColor() {
    switch (request.status) {
      case RequestStatus.pending:
        return kAccentColor;
      case RequestStatus.accepted:
        return kPrimaryColor;
      case RequestStatus.inProgress:
        return Colors.blue;
      case RequestStatus.completed:
        return kSuccessColor;
      case RequestStatus.cancelled:
        return Colors.grey;
      case RequestStatus.disputed:
        return kErrorColor;
    }
  }

  /// إرجاع نص الحالة المترجم
  String _getStatusText() {
    switch (request.status) {
      case RequestStatus.pending:
        return 'En attente';
      case RequestStatus.accepted:
        return 'Acceptée';
      case RequestStatus.inProgress:
        return 'En cours';
      case RequestStatus.completed:
        return 'Terminée';
      case RequestStatus.cancelled:
        return 'Annulée';
      case RequestStatus.disputed:
        return 'Litige';
    }
  }

  /// تنسيق تاريخ الإنشاء
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} jours';
    } else {
      return DateFormat('dd/MM').format(date);
    }
  }
}


class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showTimestamp;
  final VoidCallback? onTap;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.showTimestamp = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Nom de l'expéditeur (si ce n'est pas moi)
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 2),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            
            // Bulle de message
            Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isMe) const SizedBox(width: 40),
                
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? kPrimaryColor : Colors.grey.shade200,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                    ),
                    child: _buildMessageContent(),
                  ),
                ),
                
                if (isMe) const SizedBox(width: 40),
              ],
            ),
            
            // Horodatage et statut de lecture
            if (showTimestamp)
              Padding(
                padding: EdgeInsets.only(
                  top: 4,
                  left: isMe ? 0 : 12,
                  right: isMe ? 12 : 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMessageTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.isRead ? kPrimaryColor : Colors.grey.shade600,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.message,
          style: TextStyle(
            fontSize: 16,
            color: isMe ? Colors.white : Colors.black87,
          ),
        );
        
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: message.mediaUrl!,
                width: 200,
                height: 150,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.error),
                ),
              ),
            ),
            if (message.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message.message,
                style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ],
        );
        
      case MessageType.location:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isMe ? Colors.white : kPrimaryColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                color: isMe ? kPrimaryColor : Colors.black87,
                size: 24,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Position partagée',
                  style: TextStyle(
                    fontSize: 14,
                    color: isMe ? kPrimaryColor : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
        
      case MessageType.file:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isMe ? Colors.white : kPrimaryColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.attach_file,
                color: isMe ? kPrimaryColor : Colors.black87,
                size: 24,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.message.isNotEmpty ? message.message : 'Fichier',
                  style: TextStyle(
                    fontSize: 14,
                    color: isMe ? kPrimaryColor : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
        
      default:
        return Text(
          message.message,
          style: TextStyle(
            fontSize: 16,
            color: isMe ? Colors.white : Colors.black87,
          ),
        );
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Hier ${DateFormat('HH:mm').format(dateTime)}';
    } else if (now.difference(messageDate).inDays < 7) {
      return DateFormat('EEE HH:mm', 'fr_FR').format(dateTime);
    } else {
      return DateFormat('dd/MM HH:mm').format(dateTime);
    }
  }
}

class RatingWidget extends StatelessWidget {
  final double rating;
  final double size;
  final bool showText;
  final bool isInteractive;
  final ValueChanged<double>? onRatingChanged;
  final Color? color;
  final int maxRating;

  const RatingWidget({
    Key? key,
    required this.rating,
    this.size = 20,
    this.showText = false,
    this.isInteractive = false,
    this.onRatingChanged,
    this.color,
    this.maxRating = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? kAccentColor;

    if (isInteractive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RatingBar.builder(
            initialRating: rating,
            minRating: 0,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: maxRating,
            itemSize: size,
            itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
            itemBuilder: (context, _) => Icon(
              Icons.star,
              color: starColor,
            ),
            onRatingUpdate: onRatingChanged ?? (rating) {},
          ),
          if (showText) ...[
            const SizedBox(width: 8),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: size * 0.8,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(maxRating, (index) {
          final starRating = index + 1;
          IconData iconData;
          Color iconColor;

          if (rating >= starRating) {
            iconData = Icons.star;
            iconColor = starColor;
          } else if (rating >= starRating - 0.5) {
            iconData = Icons.star_half;
            iconColor = starColor;
          } else {
            iconData = Icons.star_border;
            iconColor = Colors.grey.shade400;
          }

          return Icon(
            iconData,
            color: iconColor,
            size: size,
          );
        }),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.8,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ],
    );
  }
}
class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double size;
  final bool showLogo;

  const LoadingWidget({
    Key? key,
    this.message,
    this.color,
    this.size = 50,
    this.showLogo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLogo) ...[
            // Logo Khidmeti
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: kPrimaryColor.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'K',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // Indicateur de chargement
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              color: color ?? kPrimaryColor,
              strokeWidth: 3,
            ),
          ),
          
          // Message de chargement
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// Widget d'erreur personnalisé
class ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;

  const ErrorWidget({
    Key? key,
    required this.message,
    this.onRetry,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: kErrorColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Widget de liste vide
class EmptyWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyWidget({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// Widget de bouton personnalisé
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;
  final bool isLoading;
  final IconData? icon;
  final bool outlined;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 50,
    this.borderRadius = 25,
    this.isLoading = false,
    this.icon,
    this.outlined = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? kPrimaryColor;
    final fgColor = textColor ?? Colors.white;

    return SizedBox(
      width: width,
      height: height,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: bgColor, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
              icon: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: bgColor,
                      ),
                    )
                  : (icon != null ? Icon(icon, color: bgColor) : const SizedBox.shrink()),
              label: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: bgColor,
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: bgColor,
                foregroundColor: fgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                elevation: 2,
              ),
              icon: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fgColor,
                      ),
                    )
                  : (icon != null ? Icon(icon, color: fgColor) : const SizedBox.shrink()),
              label: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ),
    );
  }
}