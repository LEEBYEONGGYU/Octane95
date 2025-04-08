import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await InAppWebViewController.setWebContentsDebuggingEnabled(true);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final String initialUrl = "https://gyudrive.myasustor.com/Untitled-1.html";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '옥탄가 계산기',
      home: Scaffold(
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest:  URLRequest(
                url: WebUri.uri(Uri.parse(initialUrl!))),
            onWebViewCreated: (controller) {
              print("WebView created");
            },
            onLoadStop: (controller, url) {
              print("Loaded: $url");
            },
          ),
        ),
      ),
    );
  }
}
