import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late MqttServerClient client;
  final String broker = 'test.mosquitto.org'; // Public MQTT broker address
  final String clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}'; // Unique client ID
  String latestWeather = 'No data yet';
  int pongCount = 0;
  int pingCount = 0;

  @override
  void initState() {
    super.initState();
    _setupMqttClient();
    _connectToBroker();
  }

  // Set up the MQTT client
  void _setupMqttClient() {
    client = MqttServerClient(broker, clientId);
    client.logging(on: true);
    client.setProtocolV311();
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 12000;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;
    client.onUnsubscribed = onUnsubscribed;
    client.onSubscribeFail = onSubscribeFail;
    client.pongCallback = pong;
    client.pingCallback = ping;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;
  }

  // Connect to the MQTT broker
  Future<void> _connectToBroker() async {
    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      print('MQTT::NoConnectionException - $e');
      client.disconnect();
    } on SocketException catch (e) {
      print('MQTT::SocketException - $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT::Connected to broker');
      _subscribeToTopic('weather/updates');
    } else {
      print('MQTT::ERROR - Connection failed');
      client.disconnect();
    }
  }

  // Subscribe to a topic
  void _subscribeToTopic(String topic) {
    print('MQTT::Subscribing to $topic');
    client.subscribe(topic, MqttQos.atLeastOnce);

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String message =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      setState(() {
        latestWeather = message;
      });
      print('MQTT::Received message: $message from topic: ${c[0].topic}>');
    });
  }

  // Callbacks for various MQTT client events
  void onConnected() {
    print('MQTT::Connected successfully');
  }

  void onDisconnected() {
    print('MQTT::Disconnected from broker');
    if (client.connectionStatus!.disconnectionOrigin == MqttDisconnectionOrigin.solicited) {
      print('MQTT::Disconnection was solicited');
    } else {
      print('MQTT::Disconnection was not solicited');
    }
  }

  void onSubscribed(String topic) {
    print('MQTT::Subscription confirmed for topic $topic');
  }

  void onUnsubscribed(String? topic) {
    print('MQTT::Unsubscribed from topic $topic');
  }

  void onSubscribeFail(String topic) {
    print('MQTT::Failed to subscribe to topic $topic');
  }

  void pong() {
    print('MQTT::Ping response received');
    pongCount++;
  }

  void ping() {
    print('MQTT::Ping sent');
    pingCount++;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Weather Updates'),
        ),
        body: Center(
          child: Text(
            'Latest Weather: $latestWeather',
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }
}
