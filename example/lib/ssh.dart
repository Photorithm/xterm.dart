import 'dart:async';
import 'dart:convert';

import 'package:dartssh/client.dart';
import 'package:flutter/material.dart';
import 'package:xterm/flutter.dart';
import 'package:xterm/xterm.dart';

const host = 'ssh://localhost:22';
const username = '<your username>';
const password = '<your password>';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xterm.dart demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class SSHTerminalBackend extends TerminalBackend {
  SSHClient client;

  String _host;
  String _username;
  String _password;

  final _exitCodeCompleter = Completer<int>();
  final _outStream = StreamController<String>();

  SSHTerminalBackend(this._host, this._username, this._password);

  void onWrite(String data) {
    _outStream.sink.add(data);
  }

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  void init() {
    // Use utf8.decoder to handle broken utf8 chunks
    final _sshOutput = StreamController<List<int>>();
    _sshOutput.stream.transform(utf8.decoder).listen(onWrite);

    onWrite('connecting $_host...');
    client = SSHClient(
      hostport: Uri.parse(_host),
      login: _username,
      print: print,
      termWidth: 80,
      termHeight: 25,
      termvar: 'xterm-256color',
      getPassword: () => utf8.encode(_password),
      response: (transport, data) {
        _sshOutput.add(data);
      },
      success: () {
        onWrite('connected.\n');
      },
      disconnected: () {
        onWrite('disconnected.');
        _outStream.close();
      },
    );
  }

  @override
  Stream<String> get out => _outStream.stream;

  @override
  void resize(int width, int height, int pixelWidth, int pixelHeight) {
    client.setTerminalWindowSize(width, height);
  }

  @override
  void write(String input) {
    client?.sendChannelData(utf8.encode(input));
  }

  @override
  void terminate() {
    client?.disconnect('terminate');
  }

  @override
  void ackProcessed() {
    // NOOP
  }
}

class _MyHomePageState extends State<MyHomePage> {
  Terminal terminal;
  SSHTerminalBackend backend;

  @override
  void initState() {
    super.initState();
    backend = SSHTerminalBackend(host, username, password);
    terminal = Terminal(backend: backend, maxLines: 10000);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: TerminalView(
          terminal: terminal,
        ),
      ),
    );
  }
}
