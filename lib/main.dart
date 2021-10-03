import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  'This channel is used for important notifications.', // description
  importance: Importance.high,
);

const IOSNotificationDetails iOSNotificationDetails = IOSNotificationDetails(
  // sound: 'example.mp3',
    presentAlert: true,
    presentBadge: true,
    presentSound: true
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  String _text = '';
  bool _requested = false;
  bool _fetching = false;
  late String token;
  late NotificationSettings _settings;
  FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  FirebaseFunctions functions = FirebaseFunctions.instance;

  @override
  void initState() {
    requestPermissions();
    _firebaseMessaging.getToken().then((String? _token) {
      print("$_token");
      token = _token!;
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("フォアグラウンドでメッセージを受け取りました");
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channel.description,
                  // importance: Importance.high,
                  // priority: Priority.high,
                ),
                iOS: iOSNotificationDetails
            ));
      }
    });
    super.initState();
  }

  Future<void> requestPermissions() async {

    final settings = await FirebaseMessaging.instance.requestPermission(
      announcement: true,
      carPlay: true,
      criticalAlert: true,
    );

    await flutterLocalNotificationsPlugin.initialize(
        InitializationSettings(
          iOS: IOSInitializationSettings(),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        )
    );

    setState(() {
      _requested = true;
      _fetching = false;
      _settings = settings;
    });
  }

  Future<void> sendPushNotification(String body) async {
    HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'asia-northeast1').httpsCallable('sendPushNotifications');
    try {
      final results = await callable.call(<String, dynamic>{
        'title': 'アプリからの通知',
        'body': '$body',
        'token': '$token'
      });
      print(results);
    } catch(e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'doneで送信'
                ),
                onSubmitted: (text){
                  setState(() {
                    _text = text;
                  });
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => NextPage(text: _text,),
                      )
                  );
                  sendPushNotification(text);
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class NextPage extends StatefulWidget {
  const NextPage({Key? key, required this.text}) : super(key: key);

  final String text;

  @override
  _NextPageState createState() => _NextPageState();
}

class _NextPageState extends State<NextPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NextPage'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  child: Text('${widget.text}'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

