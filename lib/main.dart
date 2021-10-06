import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'dynamic_links_service.dart';

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

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {

  String _text = '';
  late String token;
  FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  FirebaseFunctions functions = FirebaseFunctions.instance;
  final DynamicLinkService _dynamicLinkService = DynamicLinkService();
  Timer? _timerLink;

  Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      // Build後の実行した処理
      final Map<String, dynamic> map = await jsonDecode(message.data['data']);
      if(map['to'] == 'NextPage'){
        final _text = message.notification!.body?? '';
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => NextPage(text: _text,),
            transitionDuration: Duration.zero,
          ),
        );
      }
    });
  }

  Future<void> setupInteractedMessage() async {

    /// アプリを終了している状態で通知を押し、開いたときに通知データを受け取る
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _firebaseMessagingBackgroundHandler(initialMessage);
    }

    /// アプリが終了していない（バックグラウンド）の状態で通知をクリックした時に呼ばれる
    FirebaseMessaging.onMessageOpenedApp.listen(_firebaseMessagingBackgroundHandler);
  }

  @override
  void initState() {
    requestPermissions();
    _firebaseMessaging.getToken().then((String? _token) {
      print("$_token");
      token = _token!;
      // token = 'cWgH1QV9GkfKp0UQ7E0adw:APA91bGyHIQflhO9-uLibkkZ46N4Oao2dopLPFA1_r0OuVUyDJkoVv1fznkBlXh9Bgg4hZ4whzDueRomSG7S2oGrcrT7I3PnjfSIuiGLN7ff7zZ2DB9oerktr3basse53vLPMbt8EsfO';
    });

    setupInteractedMessage();

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

    WidgetsBinding.instance!.addObserver(this);

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

    print(settings);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _timerLink = Timer(
        const Duration(milliseconds: 1000),
            () {
          _dynamicLinkService.retrieveDynamicLink(context);
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    if (_timerLink != null) {
      _timerLink!.cancel();
    }
    super.dispose();
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final Uri uri = await _dynamicLinkService.createDynamicLink(id: 'hrhrrwhrje');
          showDialog(
            context: context,
            builder: (context) {
              return GestureDetector(
                onLongPress: () async {
                  final data = ClipboardData(text: uri.toString());
                  await Clipboard.setData(data);
                  print("コピーしたよ");
                },
                child: AlertDialog(
                  content: Text(
                    uri.toString()
                  ),
                ),
              );
            },
          );
        },
        child: Icon(
          CupertinoIcons.add
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

