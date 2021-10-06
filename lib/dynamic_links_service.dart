import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';

import 'main.dart';

class DynamicLinkService {

  Future<void> retrieveDynamicLink(BuildContext context) async {
    try {
      final PendingDynamicLinkData? data = await FirebaseDynamicLinks.instance.getInitialLink();
      final Uri? deepLink = data!.link;

      if (deepLink != null) {
        if(deepLink.queryParameters.containsKey('id')){
          String id = deepLink.queryParameters['id'] ?? 'id';
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => NextPage(text: '$id',)));
        }
      }

      FirebaseDynamicLinks.instance.onLink(onSuccess: (PendingDynamicLinkData? dynamicLink) async {
        if(dynamicLink!.link.queryParameters.containsKey('id')){
          String id = dynamicLink.link.queryParameters['id'] ?? 'id';
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => NextPage(text: '$id',)));
        }
      });

    } catch (e) {
      print(e.toString());
    }
  }

  Future<Uri> createDynamicLink({required String id}) async {
    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://pushnotificationapp2.page.link',
      link: Uri.parse('https://pushnotificationapp2.page.link.com/?id=$id'),
      androidParameters: AndroidParameters(
        packageName: 'com.example.push_notification_app2',
        minimumVersion: 1,
      ),
      iosParameters: IosParameters(
        bundleId: 'com.example.pushNotificationApp2',
        minimumVersion: '1',
        appStoreId: '123456789',
      ),
    );
    var dynamicUrl = await parameters.buildUrl();
    // var dynamicUrl = await parameters.buildShortLink();
    // final Uri shortUrl = dynamicUrl.shortUrl;
    return dynamicUrl;
  }

}
