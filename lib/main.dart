import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'My App',
      home: NSFiles(),
    );
  }
}

class NSFiles extends StatefulWidget {
  const NSFiles({Key? key}) : super(key: key);
  @override
  _NSFilesState createState() => _NSFilesState();
}

class _NSFilesState extends State<NSFiles> {
  var imgList = [];
  // static const domain = 'https://sdfsdf.dev/';
  static const domain = 'http://192.168.0.1/img/';
  void getHttp() async {
    try {
      var response = await Dio(BaseOptions(
        connectTimeout: 3000,
        receiveTimeout: 3000,
      )).get('http://192.168.0.1/data.json');
      var _response = jsonDecode(response.data);
      setState(() {
        imgList = _response['FileNames'];
      });
    } catch (e) {
      setState(() {
        imgList = [];
      });
    }
  }

  void _save() async {
    for (var i = 0; i < imgList.length; i++) {
      var response = await Dio(BaseOptions(
        connectTimeout: 3000,
        receiveTimeout: 3000,
      )).get('${domain + imgList[i]}',
          options: Options(responseType: ResponseType.bytes));
      await ImageGallerySaver.saveImage(
        Uint8List.fromList(response.data),
        quality: 60,
        name: "${imgList[i].split('.')[0]}",
      );
      if(i == imgList.length - 1) {
        Fluttertoast.showToast(
          msg: '保存成功',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.black,
          textColor: Colors.white,
          fontSize: 16.0
        );
      }
      
    }
  }

  @override
  void initState() {
    super.initState();
    getHttp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Switch 文件查看'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: getHttp,
            ),
          ],
        ),
        body: imgList.isNotEmpty ? _imgListWidget() : _noDataWidget());
  }

  Widget _imgListWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: imgList.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  child: Image(
                    image: NetworkImage('${domain + imgList[index]}'),
                  ),
                );
              },
            ),
          ),
          ElevatedButton(onPressed: _save, child: const Text('保存所有图片')),
        ],
      ),
    );
  }

  Widget _noDataWidget() {
    return Container(
      child: Text('没有图片'),
    );
  }
}
