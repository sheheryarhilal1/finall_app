import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert'; // Import for JSON encoding

MqttServerClient? client;

class Pannel extends StatefulWidget {
  const Pannel({super.key});

  @override
  _PannelState createState() => _PannelState();
}

class _PannelState extends State<Pannel> {
  bool isSummer = true;
  DateTime selectedDateTime = DateTime.now();
  bool isOn = false;
  RangeValues _currentRangeValues = const RangeValues(40, 80);
  final double _temperature = 30.0;
  bool _isThermostatContainerVisible = false;
  bool _isCalendarVisible = true;
  double _thermostatTemperature = 20; // Displayed as Set Point
  String mqttBroker = "test.mosquitto.org";
  String clientId = "flutter_mqtt_client";
  int port = 1883;
  String receivedMessage = ""; // Store the last received message
  String? _selectedOption; // State variable for the selected dropdown option
  double _lastDamperValue = 50; // Add a variable to store the last damper value
  int packet_id = 0;

  @override
  void initState() {
    super.initState();
    _setupMqttClient();
    _connectMqtt();
  }

  void _setupMqttClient() {
    client = MqttServerClient(mqttBroker, clientId);
    client?.port = port;
    client?.logging(on: true);
    client?.onDisconnected = _onDisconnected;
    client?.onConnected = _onConnected;
    client?.onSubscribed = _onSubscribed;
  }

  void _onDisconnected() {
    print('Disconnected from MQTT broker.');
  }

  void _onConnected() {
    print('Connected to MQTT broker.');

    // Subscribe to specified topics
    client?.subscribe('/KRC/1', MqttQos.atLeastOnce);
    client?.subscribe('/KRC/2', MqttQos.atLeastOnce);
    client?.subscribe('/KRC/3', MqttQos.atLeastOnce);
    client?.subscribe('/KRC/4', MqttQos.atLeastOnce);
    client?.subscribe('thermostat/temp', MqttQos.atLeastOnce);
    client?.subscribe('thermostat/range', MqttQos.atLeastOnce);
    client?.subscribe('thermostat/switch', MqttQos.atLeastOnce);

    client?.updates!.listen((List<MqttReceivedMessage<MqttMessage>>? c) {
      final MqttPublishMessage msg = c![0].payload as MqttPublishMessage;

      final String topic = c[0].topic;
      final String message =
          MqttPublishPayload.bytesToStringAsString(msg.payload.message);

      setState(() {
        receivedMessage = message;

        switch (topic) {
          case '/KRC/1':
            // Handle message for /KRC/1
            break;
          case '/KRC/2':
            // Handle message for /KRC/2
            break;
          case '/KRC/3':
            // Handle message for /KRC/3
            break;
          case '/KRC/4':
            // Handle message for /KRC/4
            break;
          case 'thermostat/temp':
            _thermostatTemperature =
                double.tryParse(message) ?? _thermostatTemperature;
            break;
          case 'thermostat/range':
            List<String> values = message.split('-');
            if (values.length == 2) {
              _currentRangeValues = RangeValues(
                double.tryParse(values[0]) ?? _currentRangeValues.start,
                double.tryParse(values[1]) ?? _currentRangeValues.end,
              );
            }
            break;
          case 'thermostat/switch':
            isOn = message == "ON";
            break;
        }
      });
    });
  }

  void _onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  Future<void> _connectMqtt() async {
    try {
      await client?.connect();
      print('Connected');
    } catch (e) {
      print('Exception: $e');
      client?.disconnect();
    }
  }

  void _publishMessage(String topic, String message, {bool retain = false}) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client?.publishMessage(topic, MqttQos.atMostOnce, builder.payload!,
        retain: retain);
  }

  Map<String, dynamic> _buildJsonPayload() {
    return {
      "seasonsw": isSummer,
      "dmptempsp": _thermostatTemperature,
      "dampertsw": isOn,
      "supcfm":
          "${_currentRangeValues.start.round()} - ${_currentRangeValues.end.round()}",
      "timesch": "selectedDateTime",
      "dampstate": isOn,
      "packet_id": packet_id
    };
  }


  // Create a method to publish the JSON message
  String _publishJsonMessage() {
    // ignore: unused_local_variable
    final String topic =
        '/KRC/1'; // Specify the topic where you want to publish
    packet_id++;
    final String jsonPayload = jsonEncode(_buildJsonPayload());
    // _publishMessage(topic, jsonPayload, retain: true);
    publishMessage(jsonPayload);
    return jsonPayload;
  }

  void _showDateTimePicker(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      barrierColor: const Color.fromARGB(255, 57, 218, 141),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDateTime),
        barrierColor: Colors.greenAccent,
      );

      if (pickedTime != null) {
        setState(() {
          selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          receivedMessage = "Date & Time: ${selectedDateTime.toString()}";
          _publishJsonMessage(); // Publish the complete JSON data
        });
      }
    }
  }

  void _toggleThermostatSettings() {
    setState(() {
      _isThermostatContainerVisible = !_isThermostatContainerVisible;
      _isCalendarVisible = !_isCalendarVisible;
    });
    _publishJsonMessage(); // Publish the complete JSON data
  }

  void _changeDamperValue(double value) {
    setState(() {
      _lastDamperValue = value; // Update last damper value
      _thermostatTemperature =
          value; // Update the thermostat temperature to display as Set Point
    });
    String message = "";
    message = _publishJsonMessage(); // Publish the complete JSON data
    publishMessage(message);
  }

  final TextEditingController mqttIpController = TextEditingController();
  final TextEditingController serialPortController = TextEditingController();
  final TextEditingController topicController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  String publishStatus = "";

  void publishMessage(String message) {
    const String topic = "/KRC/1";
    // const String message = "Winter";

    if (client != null) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);

      try {
        client!.publishMessage(
          topic,
          MqttQos.atLeastOnce,
          builder.payload!,
          retain: true,
        );
        setState(() {
          publishStatus =
              'Message "$message" published successfully to topic "$topic" with retain flag.';
        });
      } catch (e) {
        setState(() {
          publishStatus = 'Failed to publish message: $e';
        });
      }
    }
  }

  String _selectSeason(bool summer) {
    String message = "";
    setState(() {
      isSummer = summer;
      receivedMessage = "Season Selected: ${summer ? 'Summer' : 'Winter'}";
      message = "Season Selected: ${summer ? 'Winter' : 'Summer'}";
      message = _publishJsonMessage();
      // message =
      //     "{isSummer:true,selectedDateTime:2024-11-20T16:50:26.850414,isOn:false,temperatureRange:{start:40.0,end:80.0},thermostatTemperature:20.0,lastDamperValue:50.0,receivedMessage:Season Selected: Summer,selectedDropdownOption:null}123456789000012345";
      publishMessage(message);
    });
    // _publishJsonMessage();
    return message;
  }

  // void _selectSeason(bool summer) {
  //   setState(() {
  //     isSummer = summer;
  //     receivedMessage = "Season Selected: ${summer ? 'Summer' : 'Winter'}";
  //     _publishJsonMessage(); // Publish the complete JSON data
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Zone Master"),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            color: Colors.yellow,
            onPressed: () {
              print('Bell icon pressed');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    // Season Select Section
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Season Select",
                              style: TextStyle(fontSize: 18)),
                          // controller: messageController,

                          Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // ignore: unused_local_variable
                                  String message = _selectSeason(!isSummer);
                                  // String jsonpayloadd = _publishJsonMessage();
                                  // publishMessage(jsonpayloadd);

                                  // _selectSeason(!isSummer);
                                },
                                child: Container(
                                  width: 140,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              if (!isSummer)
                                Positioned(
                                  left: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      _selectSeason(true);
                                    },
                                    child: Container(
                                      width: 70,
                                      height: 40,
                                      color: Colors.green,
                                      child: const Center(
                                        child: Text("Summer",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16)),
                                      ),
                                    ),
                                  ),
                                ),
                              if (isSummer)
                                Positioned(
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      _selectSeason(false);
                                    },
                                    child: Container(
                                      width: 70,
                                      height: 40,
                                      color: Colors.red,
                                      child: const Center(
                                        child: Text("Winter",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16)),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    // Round Rectangle with On/Off Toggle and Gauge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            height: 270,
                            width: 30,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextButton(
                                            onPressed: () {},
                                            child: Image.asset(
                                              "assets/images/damper_vertical.png",
                                              width: 50,
                                              height: 50,
                                              color: Colors.black,
                                              colorBlendMode: BlendMode.srcIn,
                                            ),
                                          ),
                                          const Text("Set Point",
                                              style: TextStyle(fontSize: 18)),
                                          Text(
                                              "${_thermostatTemperature.round()}°C", // Display the thermostat temperature as Set Point
                                              style: const TextStyle(
                                                  fontSize: 18)),
                                        ],
                                      ),
                                      Transform.rotate(
                                        angle: -1.57,
                                        child: Switch(
                                          value: isOn,
                                          onChanged: (value) {
                                            setState(() {
                                              isOn = value;
                                              _publishJsonMessage(); // Publish the complete JSON data
                                            });
                                          },
                                          activeColor: Colors.green,
                                          inactiveThumbColor: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 50),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text(
                                        isOn ? "On" : "Off",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isOn ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          _showBottomSheet(context);
                                        },
                                        child: Image.asset(
                                          "assets/images/Temp.png",
                                          width: 35,
                                          height: 35,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 1),
                        Center(
                          child: Container(
                            height: 250,
                            width: 150,
                            padding: const EdgeInsets.all(10),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  height: 110,
                                  width: 110,
                                  child: CircularProgressIndicator(
                                    value: _temperature / 100,
                                    strokeWidth: 5,
                                    backgroundColor: Colors.white12,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.green),
                                  ),
                                ),
                                Text("$_temperature°C"),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Dual range slider inside a container
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Temperature Range",
                              style: TextStyle(fontSize: 21)),
                          const SizedBox(height: 10),
                          Container(
                            height: 150,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                          Colors.black, BlendMode.srcIn),
                                      child: GestureDetector(
                                        onLongPress: _toggleThermostatSettings,
                                        child: Image.asset(
                                          "assets/images/damper_vertical.png",
                                          width: 50,
                                          height: 50,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Text("SUPPLY CFM",
                                            style: TextStyle(fontSize: 18)),
                                        Text(
                                          "${_currentRangeValues.start.round()} - ${_currentRangeValues.end.round()}",
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                RangeSlider(
                                  values: _currentRangeValues,
                                  min: 0,
                                  max: 100,
                                  divisions: 100,
                                  labels: RangeLabels(
                                    _currentRangeValues.start
                                        .round()
                                        .toString(),
                                    _currentRangeValues.end.round().toString(),
                                  ),
                                  onChanged: (RangeValues values) {
                                    setState(() {
                                      _currentRangeValues = values;
                                      // String message = "";
                                      // message = _publishJsonMessage();
                                      // message = "";

                                      // publishMessage(message);
                                      _publishJsonMessage(); // Publish the complete JSON data
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Thermostat container based on visibility
                    if (_isThermostatContainerVisible)
                      Container(
                        height: 300,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Thermostat Settings",
                                style: TextStyle(fontSize: 20)),
                            const SizedBox(height: 10),
                            Expanded(
                              child: Center(
                                child: RotatedBox(
                                  quarterTurns: -1,
                                  child: Slider(
                                    value: _thermostatTemperature,
                                    min: 10,
                                    max: 30,
                                    divisions: 20,
                                    label:
                                        "${_thermostatTemperature.round()}°C",
                                    onChanged: (value) {
                                      setState(() {
                                        _thermostatTemperature =
                                            value; // Update Set Point
                                        _publishJsonMessage(); // Publish the complete JSON data
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Text("${_thermostatTemperature.round()}°C",
                                  style: const TextStyle(fontSize: 18)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),
                    // Calendar icon and dropdown
                    if (_isCalendarVisible)
                      Stack(
                        children: [
                          Align(
                            alignment: Alignment.bottomRight,
                            child: GestureDetector(
                              onTap: () => _showDateTimePicker(context),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(8.0),
                                child: const Icon(
                                  Icons.calendar_today,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: DropdownButton<String>(
                              value: _selectedOption, // Current selected value
                              items: <String>[
                                '/KRC/1',
                                '/KRC/2',
                                '/KRC/3',
                                '/KRC/4',
                                '/KRC/5'
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedOption =
                                      newValue; // Update selected option
                                  _publishJsonMessage(); // Publish the complete JSON data
                                });
                              },
                              underline: Container(),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return BottomSheetContent(
          onSliderChanged: _changeDamperValue,
          initialValue: _lastDamperValue, // Pass the last value
        );
      },
    ).then((value) {
      // Update last damper value when bottom sheet is closed, if any value is returned
      setState(() {
        _lastDamperValue = value ?? _lastDamperValue;
        _thermostatTemperature = _lastDamperValue; // Sync with Set Point
        _publishJsonMessage(); // Publish the complete JSON data
      });
    });
  }

  @override
  void dispose() {
    client?.disconnect();
    super.dispose();
  }
}

class BottomSheetContent extends StatefulWidget {
  final Function(double) onSliderChanged; // Callback for slider change
  final double initialValue; // Initial value for the slider

  const BottomSheetContent({
    super.key,
    required this.onSliderChanged,
    required this.initialValue,
  });

  @override
  _BottomSheetContentState createState() => _BottomSheetContentState();
}

class _BottomSheetContentState extends State<BottomSheetContent> {
  late double _sliderValue; // Use late to initialize

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.initialValue; // Initialize with the provided value
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text('Damper',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_sliderValue.toStringAsFixed(1)}°C',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 220,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 96,
                      thumbShape: SliderComponentShape.noThumb,
                      trackShape: const RectangularSliderTrackShape(),
                      activeTrackColor: Colors.blue,
                      inactiveTrackColor: Colors.grey[300],
                      overlayColor: Colors.transparent,
                    ),
                    child: Slider(
                      value: _sliderValue,
                      min: 0,
                      max: 100,
                      onChanged: (double value) {
                        setState(() {
                          _sliderValue = value; // Update the local slider value
                        });
                        widget.onSliderChanged(value); // Notify parent
                      },
                      onChangeEnd: (double value) {
                        Navigator.pop(context,
                            value); // Return the value when slider is released
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(_sliderValue); // Pass value when close
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
