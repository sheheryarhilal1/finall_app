import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';

void main() {
  runApp(MyApp());
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
      home: QRCodeScanner(),
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
  List<Map<String, String>> scannedDataList = [];
  String? ssid;
  String? password;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.location.request();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isScanning) {
      setState(() {
        isScanning = true;
        cameraController.start();
      });
    }
  }

  void _parseQRCode(String code) {
    final wifiRegex = RegExp(
        r'WIFI:T:[^;]*;S:(?<ssid>[^;]*);P:(?<password>[^;]*);H:(?:true|false);;');
    final wifiMatch = wifiRegex.firstMatch(code);

    if (wifiMatch != null) {
      setState(() {
        ssid = wifiMatch.namedGroup('ssid');
        password = wifiMatch.namedGroup('password');
      });

      _showSaveDialog();
    } else {
      _navigateToConnectionStatusScreen("Non-Wi-Fi QR code: $code");
    }
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Save QR Code'),
          content: Text('Do you want to save this QR code data?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  scannedDataList.add({
                    'ssid': ssid!,
                    'password': password!,
                    'status': 'Pending',
                  });
                });
                Navigator.pop(context);
                _showSaveConfirmation();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSaveConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text('QR Code saved successfully!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToConnectionStatusScreen(String message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConnectionStatusScreen(
            connectionResult: message, scannedDataList: scannedDataList),
      ),
    ).then((_) {
      setState(() {
        isScanning = true;
        cameraController.start();
      });
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Code Scanner'),
        actions: [
          IconButton(
            icon: Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.all(16),
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
                : Center(child: Text('Scanning stopped')),
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

class ConnectionStatusScreen extends StatelessWidget {
  final String connectionResult;
  final List<Map<String, String>> scannedDataList;

  const ConnectionStatusScreen({
    super.key,
    required this.connectionResult,
    required this.scannedDataList,
  });

  Future<void> _connectToWiFi(
      BuildContext context, String ssid, String password) async {
    bool connectionResult =
        await WiFiForIoTPlugin.findAndConnect(ssid, password: password);
    String connectionStatus = connectionResult ? 'Connected' : 'Failed';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(connectionResult
              ? 'Connected to $ssid'
              : 'Failed to connect to $ssid')),
    );

    Navigator.pop(context);
  }

  void _showWiFiDetailsDialog(BuildContext context, Map<String, String> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Wi-Fi Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SSID: ${data['ssid']}'),
              Text('Password: ${data['password']}'),
              Text('Connection Status: ${data['status']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () {
                _connectToWiFi(context, data['ssid']!, data['password']!);
              },
              child: Text('Connect'),
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
        title: Text('Connection Status'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: scannedDataList.length,
                itemBuilder: (context, index) {
                  final data = scannedDataList[index];
                  return GestureDetector(
                    onTap: () {
                      _showWiFiDetailsDialog(context, data);
                    },
                    child: Container(
                      margin: EdgeInsets.all(8),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SSID: ${data['ssid']}',
                              style: TextStyle(color: Colors.white)),
                          Text('Password: ${data['password']}',
                              style: TextStyle(color: Colors.white)),
                          Text('Connection Status: ${data['status']}',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
