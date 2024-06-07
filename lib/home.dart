import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rubiks_cube_solver/solve.dart';
import 'package:rubiks_cube_solver/state/data_state.dart';
import 'package:scoped_model/scoped_model.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final picker = ImagePicker();
  bool loading = false;
  final server_url = "http://192.168.43.75:5000/";  // Update with your actual server URL or IP

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<DataState>(builder: (context, child, model) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Rubik's Cube Solver"),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 20),
              buildRow(["top", "left"], [Colors.yellow[600]!, Colors.blue]),
              SizedBox(height: 20),
              buildRow(["front", "right"], [Colors.red, Colors.green]),
              SizedBox(height: 20),
              buildRow(["back", "bottom"], [Colors.orange, Colors.grey[300]!]),
              SizedBox(height: 100),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Builder(
          builder: (BuildContext _context) {
            return ButtonTheme(
              minWidth: MediaQuery.of(context).size.width,
              height: 50,
              child: ElevatedButton(
                onPressed: model.sideColorCode.containsValue("")
                    ? null
                    : () {
                  setState(() {
                    loading = true;
                  });
                  solveCube(_context);
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Colors.indigo[800],
                ),
                child: loading
                    ? Container(
                  height: 40,
                  child: SpinKitThreeBounce(
                    size: 18,
                    color: Colors.white,
                  ),
                )
                    : Text("Solve", style: TextStyle(fontSize: 14)),
              ),
            );
          },
        ),
      );
    });
  }

  void _alertBox(String path, String side) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ScopedModelDescendant<DataState>(
          builder: (context, child, model) {
            return Dialog(
              insetPadding: EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: model.processing
                  ? buildProcessingDialog(path)
                  : buildColorConfirmationDialog(model, side),
            );
          },
        );
      },
    );
  }

  Widget buildProcessingDialog(String path) {
    return Container(
      margin: EdgeInsets.all(15),
      height: 300.0,
      width: 300.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: FileImage(File(path)),
          fit: BoxFit.fitHeight,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black45,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitCubeGrid(color: Colors.white, size: 40.0),
            SizedBox(height: 15),
            Text("Image Is Processing...", style: TextStyle(fontSize: 15, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget buildColorConfirmationDialog(DataState model, String side) {
    return Container(
      margin: EdgeInsets.all(15),
      height: 300.0,
      width: 300.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: model.error
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            model.errorText,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Try Again", style: TextStyle(color: Colors.blue)),
          ),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Are the colors matched?",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          GreyContainer(BoxColors(model.tempRGB), "", Colors.transparent),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("Try Again", style: TextStyle(color: Colors.blue)),
              ),
              ElevatedButton(
                onPressed: () {
                  model.setsideColor(side, model.tempRGB);
                  model.setsideColorCode(side, model.tempColorCode);
                  Navigator.pop(context);
                },
                child: Text("Done", style: TextStyle(color: Colors.green)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void solveCube(BuildContext context) async {
    DataState dataState = ScopedModel.of<DataState>(context);
    String colorCode = dataState.sideColorCode["top"]! +
        dataState.sideColorCode["left"]! +
        dataState.sideColorCode["front"]! +
        dataState.sideColorCode["right"]! +
        dataState.sideColorCode["back"]! +
        dataState.sideColorCode["bottom"]!;
    print(colorCode);
    try {
      Response response = await Dio().get(server_url + "solve?colors=" + colorCode);

      setState(() {
        loading = false;
      });
      if (response.data["status"] == false) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Wrong color pattern, Try again...'),
        ));
      } else {
        dataState.setrotations(response.data["rotations"]);
        Navigator.push(context, MaterialPageRoute(builder: (context) => SolveCube()));
      }
    } catch (e) {
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Server error, Try again...'),
      ));
    }
  }

  Future<void> getImage(String side) async {
    DataState dataState = ScopedModel.of<DataState>(context);
    dataState.setProcessing(false);
    dataState.seterror(false);
    dataState.settempRGB([]);
    dataState.settempColorCode("");

    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxHeight: 1600,
      maxWidth: 1000,
    );

    if (pickedFile == null) return;

    dataState.setProcessing(true);
    _alertBox(pickedFile.path, side);

    try {
      FormData formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(pickedFile.path, filename: "upload.jpeg"),
      });

      Response response = await Dio().post(server_url, data: formData);
      dataState.setProcessing(false);
      dataState.settempRGB(response.data["color_rgb"]);
      dataState.settempColorCode(response.data["color_name"]);

      if (response.data["status"] == false) {
        dataState.seterror(true);
        dataState.seterrorText("Unable to detect colors, try again...");
      }
    } catch (e) {
      dataState.setProcessing(false);
      dataState.seterror(true);
      dataState.seterrorText("Server Error");
    }
  }

  Widget buildRow(List<String> sides, List<Color> colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: sides
          .asMap()
          .entries
          .map((entry) => GreyContainer(checkSide(entry.value), entry.value.capitalize(), colors[entry.key]))
          .toList(),
    );
  }

  Widget checkSide(String side) {
    DataState dataState = ScopedModel.of<DataState>(context);
    return dataState.sideColor[side.toLowerCase()].isNotEmpty
        ? BoxColors(dataState.sideColor[side.toLowerCase()]!)
        : getImageButton(side);
  }

  Widget getImageButton(String side) {
    return InkWell(
      onTap: () => getImage(side),
      child: Icon(Icons.add, size: 40),
    );
  }

  Widget GreyContainer(Widget widget, String side, Color color) {
    return ScopedModelDescendant<DataState>(builder: (context, child, model) {
      return Container(
        width: 160,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(side, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                side.isNotEmpty && model.sideColor[side.toLowerCase()]!.isNotEmpty
                    ? InkWell(
                  onTap: () {
                    model.setsideColor(side.toLowerCase(), []);
                  },
                  child: Icon(Icons.replay, size: 20, color: Colors.green[700]),
                )
                    : Container(),
              ],
            ),
            SizedBox(height: 3),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[300],
              ),
              width: 160,
              height: 160,
              child: widget,
            ),
            SizedBox(height: 3),
            side.isNotEmpty
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("***Center must:  ", style: TextStyle(fontSize: 12)),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: color,
                  ),
                  width: 12,
                  height: 12,
                )
              ],
            )
                : Container(),
          ],
        ),
      );
    });
  }

  Widget ColorContainer(List rgb) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Color.fromRGBO(rgb[0], rgb[1], rgb[2], 1.0),
      ),
      width: 40,
      height: 40,
    );
  }

  Widget BoxColors(List rgb) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ColorContainer(rgb[0]),
            ColorContainer(rgb[1]),
            ColorContainer(rgb[2]),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ColorContainer(rgb[3]),
            ColorContainer(rgb[4]),
            ColorContainer(rgb[5]),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ColorContainer(rgb[6]),
            ColorContainer(rgb[7]),
            ColorContainer(rgb[8]),
          ],
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
