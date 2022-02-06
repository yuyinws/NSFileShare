import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:photo_view/photo_view.dart';
import 'package:permission_handler/permission_handler.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:ext_storage/ext_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:percent_indicator/percent_indicator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSFileShare',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const NSFiles(),
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
  var consoleName = '';
  var downloadPath = '';
  var fileType = '';
  var isDownloading = false;
  double progress = 0;
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  // static const domain = 'https://sdfsdf.dev/';
  static const domain = 'http://192.168.0.1/img/';
  void getHttp() async {
    try {
      var response = await Dio(BaseOptions(
        connectTimeout: 2000,
        receiveTimeout: 2000,
      )).get('http://192.168.0.1/data.json');
      print(response);
      var _response = jsonDecode(response.data);
      setState(() {
        imgList = _response['FileNames'];
        consoleName = _response['ConsoleName'];
        fileType = _response['FileType'];
        if (fileType == 'movie') {
          _controller = VideoPlayerController.network(
            '$domain${imgList[0]}',
          );
          _initializeVideoPlayerFuture = _controller.initialize();
        }
      });
    } catch (e) {
      setState(() {
        imgList = [];
      });
      Fluttertoast.showToast(
        msg: '未检测到Switch热点',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  void _save() async {
    for (var i = 0; i < imgList.length; i++) {
      var response = await Dio(BaseOptions(
        connectTimeout: 3000,
        receiveTimeout: 3000,
      )).get(domain + imgList[i],
          options: Options(responseType: ResponseType.bytes));
      await ImageGallerySaver.saveImage(
        Uint8List.fromList(response.data),
        quality: 100,
        name: "${imgList[i].split('.')[0]}",
      );
      if (i == imgList.length - 1) {
        Fluttertoast.showToast(
          msg: '保存成功',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.black,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }
  }

  void _phoneView(url) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return PhotoView(
        imageProvider: NetworkImage(url),
      );
    }));
  }

  void _downloadFile(Dio dio, downloadUrl, savePath) async {
    var response = await dio.get(
      downloadUrl,
      onReceiveProgress: showDownloadProgress,
      //Received data with List<int>
      options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          validateStatus: (status) {
            return status! < 500;
          }),
    );
    File file = File(savePath);
    var raf = file.openSync(mode: FileMode.write);
    // response.data is List<int> type
    raf.writeFromSync(response.data);
    await raf.close();
  }

  void showDownloadProgress(received, total) {
    setState(() {
      isDownloading = true;
      progress = received / total;
      if (received == total) {
        isDownloading = false;
        Fluttertoast.showToast(
          msg: '下载完成',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.black,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    });
  }

  _saveVideo() async {
    Dio dio = Dio();
    final directory = await ExtStorage.getExternalStoragePublicDirectory(
        ExtStorage.DIRECTORY_DOWNLOADS);
    Permission permission = Permission.storage;
    PermissionStatus status = await permission.status;
    if (status != PermissionStatus.granted) {
      Map<Permission, PermissionStatus> statuses = await [permission].request();
      if (statuses[permission] == PermissionStatus.granted) {
        print('权限申请成功');
        _downloadFile(
          dio,
          '$domain${imgList[0]}',
          '$directory/${DateTime.now().millisecondsSinceEpoch}-${imgList[0]}',
        );
      } else {
        print('权限申请失败');
      }
      print(statuses);
    } else {
      _downloadFile(
        dio,
        '$domain${imgList[0]}',
        '$directory/${DateTime.now().millisecondsSinceEpoch}-${imgList[0]}',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    getHttp();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Switch 文件分享'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: getHttp,
            ),
          ],
        ),
        body: Builder(
          builder: (context) {
            if (imgList.isNotEmpty) {
              if (fileType == 'photo') {
                return _imgListWidget();
              } else {
                return _videoListWidget();
              }
            } else {
              return _noDataWidget();
            }
          },
        ));
  }

  Widget _videoListWidget() {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // If the VideoPlayerController has finished initialization, use
          // the data it provides to limit the aspect ratio of the video.
          return Container(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    "已连接至：$consoleName",
                    style: const TextStyle(fontSize: 16, color: Colors.green),
                  ),
                ),
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  // Use the VideoPlayer widget to display the video.
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      VideoPlayer(_controller),
                      VideoProgressIndicator(_controller, allowScrubbing: true),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            // If the video is playing, pause it.
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              // If the video is paused, play it.
                              _controller.play();
                            }
                          });
                        },
                        child: const Text('播放/暂停'),
                      ),
                      ElevatedButton(
                        onPressed: _saveVideo,
                        child: const Text('下载视频'),
                      ),
                    ],
                  ),
                ),
                isDownloading
                    ? Padding(
                        padding: const EdgeInsets.only(top: 150),
                        child: CircularPercentIndicator(
                          radius: 100.0,
                          lineWidth: 10.0,
                          percent: progress,
                          center: const Icon(
                            Icons.download,
                            size: 50.0,
                            color: Colors.red,
                          ),
                          backgroundColor: Colors.grey,
                          progressColor: Colors.red,
                        ),
                      )
                    : Container(),
              ],
            ),
          );
        } else {
          // If the VideoPlayerController is still initializing, show a
          // loading spinner.
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }

  Widget _imgListWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              "已连接至：$consoleName",
              style: const TextStyle(fontSize: 16, color: Colors.green),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: imgList.length,
              itemBuilder: (context, index) {
                return Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                    child: GestureDetector(
                      child: Image(
                        image: NetworkImage(domain + imgList[index]),
                      ),
                      onTap: () {
                        _phoneView(domain + imgList[index]);
                      },
                    ));
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
      width: double.infinity,
      margin: const EdgeInsets.only(top: 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Image(image: AssetImage('assets/offline.png'), width: 100),
          Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              '未连接至Switch热点',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 100),
            child: Text(
              '使用方法：\n1.将Switch中的图片「发送到智能手机」\n2.连接至Switch热点\n3.点击右上角的刷新按钮',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
