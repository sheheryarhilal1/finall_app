import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
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
  // ignore: library_private_types_in_public_api
  _QRCodeScannerState createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScanner> {
  bool isScanning = true;
  MobileScannerController cameraController = MobileScannerController();
  List<Map<String, String>> scannedConnections = [];

  // To track the selected tab for the bottom navigation
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
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

  // Handle the tab change
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (_selectedIndex == 1) {
        // Navigate to ConnectionResultScreen when the 'Device' tab is tapped
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
        // Navigate to SettingsScreen when the 'Settings' tab is tapped
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
      // Bottom Navigation Bar
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
  // ignore: library_private_types_in_public_api
  _ConnectionResultScreenState createState() => _ConnectionResultScreenState();
}

class _ConnectionResultScreenState extends State<ConnectionResultScreen> {
  String? ssid;
  String? password;
  String? connectionStatus = 'Not Connected';

  int _selectedIndex = 0;

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

  // Method to connect to the Wi-Fi network when SSID and password are tapped
  Future<void> _connectToWiFi(String ssid, String password) async {
    bool result =
        await WiFiForIoTPlugin.findAndConnect(ssid, password: password);
    String connectionStatusMessage =
        result ? 'Connected to $ssid' : 'Failed to connect to $ssid';

    setState(() {
      connectionStatus = connectionStatusMessage;
    });

    // Show the connection status to the user
    showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result ? 'Success' : 'Failure'),
        content: Text(connectionStatusMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Handle the selection of bottom navigation items
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Navigate to the selected screen (Home or Settings)
    if (_selectedIndex == 0) {
      // Navigate to Home
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Work()), // Replace with your HomeScreen
      );
    } else if (_selectedIndex == 1) {
      // Navigate to Settings
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                SettingsScreen()), // Replace with your SettingsScreen
      );
    }
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
                // Display the SSID and Password if available
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Settings screen that will be displayed when the "Settings" tab is tapped
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _sliderValue1 = 0.5;
  double _sliderValue2 = 0.5;
  double _sliderValue3 = 0.5;
  bool _sensorBorderEnabled = false; // Track the state of the switch
  int _selectedIndex = 0; // Track the selected tab index

  // Function to handle tab change
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 2) {
      // If the device icon is pressed (index 2), navigate to ConnectionScreenStatus
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConnectionResultScreen(
            result:
                'Connected to MyWiFi;P:mySecretPassword', // Example result string
            connections: [
              {'ssid': 'BITA_RMS', 'password': '123456789'},
              {'ssid': 'ZMD-AAA012', 'password': 'bitahomes'}
            ], // Example list of connections
          ),
        ),
      );
    }
    // If the home icon is pressed (index 1), navigate to Work screen
    else if (index == 1) {
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
            // Existing sliders and sensor border section

            // First slider with clock icon
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
            // Second slider with brightness icon
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
            // Third slider with clock icon
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
            // Sensor Border Section
            Container(
              margin: const EdgeInsets.only(top: 16.0),
              padding: const EdgeInsets.all(10), // Padding for inner spacing
              decoration: BoxDecoration(
                border: Border.all(
                  color: _sensorBorderEnabled
                      ? Colors.blue
                      : Colors
                          .grey, // Change border color based on the switch state
                  width: 2.0, // Border width
                ),
                borderRadius: BorderRadius.circular(8), // Rounded corners
              ),
              child: Row(
                children: [
                  const Icon(Icons.monitor), // Monitor icon on the left
                  const SizedBox(width: 10),
                  const Text(
                    'Sensor Border',
                    style: TextStyle(fontSize: 18),
                  ),
                  const Spacer(), // Push the switch to the right
                  Switch(
                    value: _sensorBorderEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _sensorBorderEnabled = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            // Sign Out Button
            Container(
              margin: const EdgeInsets.only(top: 32.0),
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to the new screen
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
      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex, // Set the current index
        onTap: _onItemTapped, // Handle tab selection
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
            icon: Icon(Icons
                .devices), // The device icon to navigate to ConnectionScreenStatus
            label: 'Device',
          ),
        ],
      ),
    );
  }
}
