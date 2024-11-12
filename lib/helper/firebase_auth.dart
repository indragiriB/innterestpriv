import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseAuthHelper {
  static Future<User?> registerUsingEmailPassword({
    required String name,
    required String email,
    required String password,
    required String fullname,
    required String address,
  }) async {
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseDatabase database = FirebaseDatabase.instance;
    User? user;

    try {
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = userCredential.user;
      await user!.updateProfile(displayName: name);
      await user.reload();
      user = auth.currentUser;
      String userId = user!.uid;

      // Save user data to Realtime Database
      if (user != null) {
        await database.ref('users/${user.uid}').set({
          'userId': userId,
          'name': name,
          'email': email,
          'fullname': fullname,
          'address': address,
        });

        // Add album data for the new user
        await database.ref('albums/${user.uid}').set({
          'albumId': userId,
          'createdAt': DateTime.now().toIso8601String(),
          'albumName': '${name}\'s Album',
          'description': 'Album created by $name',
          'userId': userId,
        });
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        print('The account already exists for that email.');
      }
    } catch (e) {
      print(e);
    }

    return user;
  }

  static Future<User?> signInUsingEmailPassword({
    required String email,
    required String password,
  }) async {
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseDatabase database = FirebaseDatabase.instance;
    User? user;

    try {
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = userCredential.user;

      // Save user data to Realtime Database
      if (user != null) {
        await database.ref('users/${user.uid}').update({
          'email': email,
        });

        // Check if album data exists, if not, add it
        final albumSnapshot = await database.ref('albums/${user.uid}').get();
        if (!albumSnapshot.exists) {
          await database.ref('albums/${user.uid}').set({
            'albumId': user.uid,
            'createdAt': DateTime.now().toIso8601String(),
            'albumName': '${user.displayName}\'s Album',
            'description': 'Album created by ${user.displayName}',
            'userId': user.uid,
            'postIds': [], // Inisialisasi list post kosong
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided.');
      }
    }

    return user;
  }
}
