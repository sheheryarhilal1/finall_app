import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:testappbita/Device/pannel.dart';
import 'package:testappbita/open_folder/singin.dart';

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
  String? _previousSSID;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _getCurrentSSID();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.location.request();
  }

  Future<void> _getCurrentSSID() async {
    _previousSSID = await WiFiForIoTPlugin.getSSID();
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
        //  _showWiFiDialog(ssid);
      }
    } else {
      _navigateToResultScreen("Non-Wi-Fi QR code scanned: $code");
    }
  }

  void _showConnectionDialog(String ssid, String defaultPassword) {
    TextEditingController nameController = TextEditingController();
    TextEditingController passwordController =
        TextEditingController(text: defaultPassword);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Connect to Wi-Fi'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(labelText: 'Connection Name'),
                ),
                TextField(
                  controller: TextEditingController(text: ssid),
                  decoration: const InputDecoration(labelText: 'SSID'),
                  readOnly: true,
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Connect'),
              onPressed: () {
                final name = nameController.text;
                final password = passwordController.text;
                if (name.isNotEmpty) {
                  _connectToWiFi(ssid, password);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please provide a name.")),
                  );
                }
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Send'),
              onPressed: () {
                disconnectwifi();
                // if (_previousSSID != null) {
                //   String placeholderPassword = '';
                //   _connectToWiFi(
                //           _previousSSID!, placeholderPassword, "Main Wi-Fi")
                //       .then((success) {
                //     if (success) {
                //       Navigator.of(context).pop();
                //       Navigator.pushReplacement(
                //         context,
                //         MaterialPageRoute(builder: (context) => const Pannel()),
                //       );
                //     } else {
                //       ScaffoldMessenger.of(context).showSnackBar(
                //         const SnackBar(
                //             content: Text("Failed to connect to Main Wi-Fi.")),
                //       );
                //     }
                //   });
                // } else {
                //   ScaffoldMessenger.of(context).showSnackBar(
                //     const SnackBar(
                //         content: Text("No previous Wi-Fi connection found.")),
                //   );
                // }
              },
            ),
          ],
        );
      },
    );
  }

  void diconnectwifi() async {
    final disconnectedd = await WiFiForIoTPlugin.disconnect();
    if (disconnectedd) {
      print("Disconnected");
    } else {
      print("Not Disconnected");
    }
  }

  Future<bool> _connectToWiFi(String ssid, String password) async {
    bool result =
        await WiFiForIoTPlugin.findAndConnect(ssid, password: password);

    String connectionStatus =
        result ? 'Connected to $ssid' : 'Failed to connect to $ssid';

    _navigateToResultScreen(connectionStatus, ssid, password);
    if (result) {
      _showWiFiDialog(ssid, password);
    } else {
      print("Not Connected  with Damper");
    }
    return result;
  }

  void _navigateToResultScreen(String result,
      [String? ssid, String? password, String? name]) {
    setState(() {
      if (ssid != null && password != null && name != null) {
        scannedConnections
            .add({'ssid': ssid, 'password': password, 'name': name});
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
        isScanning = true;
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

  void _showWiFiDialog(String ssid, String password) {
    TextEditingController nameController = TextEditingController();
    TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Connect Damper to Wi-Fi'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(labelText: 'Connection Name'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            // TextButton(
            //   child: const Text('Connect'),
            //   onPressed: () {
            //     final ssidd = nameController.text;
            //     final pass = passwordController.text;
            //     if (ssidd.isNotEmpty) {
            //       _connectToWiFi(ssid, password);
            //     } else {
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(content: Text("Please provide a name.")),
            //       );
            //     }
            //     Navigator.of(context).pop();
            //   },
            // ),
            TextButton(
              child: const Text('Send'),
              onPressed: () {
                final ssidd = nameController.text;
                final pass = passwordController.text;
                if (ssidd != null) {
                  // String placeholderPassword =
                  //     ''; // Placeholder, could be customized
                  diconnectwifi();
                  String connectionStatus = true
                      ? 'Connected to $ssid'
                      : 'Failed to connect to $ssid';

                  // _navigateToResultScreen(connectionStatus, ssid, password);

                  // _connectToWiFi(ssid, placeholderPassword);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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

void disconnectwifi() async {
  final disconnectedd = await WiFiForIoTPlugin.disconnect();
  if (disconnectedd) {
    print("Disconnected");
  } else {
    print("Not Disconnected");
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

  void diconnectwifi() async {
    final disconnectedd = await WiFiForIoTPlugin.disconnect();
    if (disconnectedd) {
      print("Disconnected");
    } else {
      print("Not Disconnected");
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

    if (result) {
      // Navigate to the Pannel screen directly upon a successful connection
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Pannel()),
      );
    } else {
      _showConnectionStatusDialog(context, connectionStatusMessage);
    }
  }

  void _showConnectionStatusDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message.contains('Failed') ? 'Failure' : 'Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showWiFiDialog(String ssid) {
    TextEditingController nameController = TextEditingController();
    TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Connect to Existing Wi-Fi'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(labelText: 'Connection Name'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Connect'),
              onPressed: () {
                final name = nameController.text;
                final password = passwordController.text;
                if (name.isNotEmpty) {
                  _connectToWiFi(ssid, password);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please provide a name.")),
                  );
                }
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Switch to Main Wi-Fi'),
              onPressed: () {
                if (ssid != null) {
                  String placeholderPassword =
                      ''; // Placeholder, could be customized
                  diconnectwifi();
                  // _connectToWiFi(ssid, placeholderPassword);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              GestureDetector(
                onTap: () {
                  // Navigate to the new screen when tapped
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Pannel()),
                  );
                },
                child: Align(
                  alignment:
                      Alignment.centerLeft, // Aligns the container to the left
                  child: Container(
                    height: 250,
                    width: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red),
                      color: Colors.grey, // Add a background color
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment
                          .start, // Align children to the start
                      children: [
                        if (ssid != null)
                          Container(
                            alignment: Alignment
                                .center, // Centers the content inside the container
                            child: Text(
                              '$ssid',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16), // Spacing between widgets
                        Center(
                          child: const Text(
                            'Damper',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16), // Additional spacing
                      ],
                    ),
                  ),
                ),
              ),

              // Displaying the list of connections
              Expanded(
                child: ListView.builder(
                  itemCount: widget.connections.length,
                  itemBuilder: (context, index) {
                    final connection = widget.connections[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(
                          connection['name'] ?? 'Unknown Connection',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(connection['ssid'] ?? 'Unknown SSID'),
                        trailing: const Icon(Icons.wifi),
                        onTap: () {
                          // _showConnectionDialog(
                          // context,
                          // connection['ssid'] ??
                          //     ''); // Ensure a valid string
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
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Pannel()),
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
                    MaterialPageRoute(builder: (context) => const Signin()),
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
