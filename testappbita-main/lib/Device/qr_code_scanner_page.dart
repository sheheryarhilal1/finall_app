import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:testappbita/Device/pannel.dart';
import 'package:testappbita/Home_Screen/Home.dart';
import 'package:testappbita/open_folder/singin.dart';
import 'package:wifi_iot/wifi_iot.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Code Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const QRCodeScanner(),
    );
  }
}

class QRCodeScanner extends StatefulWidget {
  const QRCodeScanner({super.key});

  @override
  _QRCodeScannerState createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScanner> {
  bool isScanning = true;
  MobileScannerController cameraController = MobileScannerController();
  List<Map<String, String>> scannedConnections = [];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    // No need to load connections since we're removing shared preferences
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.location.request();
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty && isScanning) {
      final String? code = capture.barcodes.first.rawValue;
      if (code != null) {
        setState(() {
          isScanning = false;
          cameraController.stop();
        });
        _parseQRCode(code);
      }
    }
  }

  void _parseQRCode(String code) {
    final wifiRegex = RegExp(
        r'WIFI:T:[^;]*;S:(?<ssid>[^;]*);P:(?<password>[^;]*);H:(?:true|false);;');
    final wifiMatch = wifiRegex.firstMatch(code);

    if (wifiMatch != null) {
      final ssid = wifiMatch.namedGroup('ssid');
      final password = wifiMatch.namedGroup('password');
      if (ssid != null && password != null) {
        _connectToWiFi(ssid, password);
      }
    } else {
      _navigateToResultScreen("Non-Wi-Fi QR code scanned: $code");
    }
  }

  Future<void> _connectToWiFi(String ssid, String password) async {
    bool result =
        await WiFiForIoTPlugin.findAndConnect(ssid, password: password);
    String connectionStatus =
        result ? 'Connected to $ssid' : 'Failed to connect to $ssid';

    _navigateToResultScreen(connectionStatus, ssid, password);
  }

  void _navigateToResultScreen(String result,
      [String? ssid, String? password]) {
    setState(() {
      if (ssid != null && password != null) {
        scannedConnections.add({'ssid': ssid, 'password': password});
        // Removed the saving to shared preferences
      }
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConnectionResultScreen(
            result: result, connections: scannedConnections),
      ),
    ).then((_) {
      setState(() {
        isScanning =
            true; // Enable scanning again when we pop the result screen.
        cameraController.start();
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (_selectedIndex == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConnectionResultScreen(
              result: "Scanned Connections",
              connections: scannedConnections,
            ),
          ),
        );
      } else if (_selectedIndex == 2) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SettingsScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isScanning
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MobileScanner(
                      controller: cameraController,
                      onDetect: _onDetect,
                    ),
                  )
                : const Center(child: Text('Scanning stopped')),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Device',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

class ConnectionResultScreen extends StatefulWidget {
  final String result;
  final List<Map<String, String>> connections;

  const ConnectionResultScreen(
      {super.key, required this.result, required this.connections});

  @override
  _ConnectionResultScreenState createState() => _ConnectionResultScreenState();
}

class _ConnectionResultScreenState extends State<ConnectionResultScreen> {
  String? ssid;
  String? password;
  String? connectionStatus = 'Not Connected';

  @override
  void initState() {
    super.initState();
    _parseResult();
  }

  void _parseResult() {
    final wifiRegex =
        RegExp(r'Connected to (?<ssid>[^\n;]+)(?:;P:(?<password>[^\n]+))?');
    final match = wifiRegex.firstMatch(widget.result);

    if (match != null) {
      setState(() {
        ssid = match.namedGroup('ssid');
        password = match.namedGroup('password');
      });
    } else {
      setState(() {
        ssid = widget.result;
        password = null; // No password detected
      });
    }
  }

  Future<void> _connectToWiFi(String ssid, String password) async {
    bool result =
        await WiFiForIoTPlugin.findAndConnect(ssid, password: password);
    String connectionStatusMessage =
        result ? 'Connected to $ssid' : 'Failed to connect to $ssid';

    setState(() {
      connectionStatus = connectionStatusMessage;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result ? 'Success' : 'Failure'),
        content: Text(connectionStatusMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (result) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Pannel(),
                  ),
                );
              }
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device'),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border.all(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ssid != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: connectionStatus!.contains('Failed')
                        ? Colors.red[100]
                        : Colors.green[100],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SSID: $ssid',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (password != null)
                        Text(
                          'Password: $password',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        )
                      else
                        const Text(
                          'Password not available.',
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Connection Status: $connectionStatus',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: connectionStatus!.contains('Failed')
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Scanned Connections:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.connections.length,
                  itemBuilder: (context, index) {
                    final connection = widget.connections[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(connection['ssid'] ?? 'Unknown SSID'),
                        subtitle: Text(connection['password'] ?? 'No password'),
                        onTap: () {
                          if (connection['password'] != null) {
                            _connectToWiFi(
                                connection['ssid']!, connection['password']!);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _sliderValue1 = 0.5;
  double _sliderValue2 = 0.5;
  double _sliderValue3 = 0.5;
  bool _sensorBorderEnabled = false;
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Work()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.access_time),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dashboard item opacity',
                          style: TextStyle(fontSize: 18),
                        ),
                        Slider(
                          value: _sliderValue1,
                          min: 0,
                          max: 1,
                          onChanged: (value) {
                            setState(() {
                              _sliderValue1 = value;
                            });
                          },
                        ),
                        Text('Value: ${_sliderValue1.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.brightness_6),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Device item opacity',
                          style: TextStyle(fontSize: 18),
                        ),
                        Slider(
                          value: _sliderValue2,
                          min: 0,
                          max: 1,
                          onChanged: (value) {
                            setState(() {
                              _sliderValue2 = value;
                            });
                          },
                        ),
                        Text('Value: ${_sliderValue2.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.access_time),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data interval',
                        style: TextStyle(fontSize: 18),
                      ),
                      Slider(
                        value: _sliderValue3,
                        min: 0,
                        max: 1,
                        onChanged: (value) {
                          setState(() {
                            _sliderValue3 = value;
                          });
                        },
                      ),
                      Text('Value: ${_sliderValue3.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 32.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Signin()),
                  );
                },
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Device',
          ),
        ],
      ),
    );
  }
}
