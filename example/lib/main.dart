import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/android_encoder.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat;

enum t_MEDIA {
  FILE,
  BUFFER,
  ASSET,
  STREAM,
  REMOTE_EXAMPLE_FILE,
}

void main() {
  runApp(new MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isRecording = false;
  List<String> _path = [null, null, null, null, null, null, null];
  StreamSubscription _recorderSubscription;
  StreamSubscription _dbPeakSubscription;
  StreamSubscription _playerSubscription;
  StreamSubscription _playbackStateSubscription;
  FlutterSound flutterSound;

  String _recorderTxt = '00:00:00';
  String _playerTxt = '00:00:00';
  double _dbLevel;

  double sliderCurrentPosition = 0.0;
  double maxDuration = 1.0;
  t_MEDIA _media = t_MEDIA.REMOTE_EXAMPLE_FILE;
  t_CODEC _codec = t_CODEC.CODEC_AAC;

  // Whether the media player has been initialized and the UI controls can
  // be displayed.
  bool _canDisplayPlayerControls = false;
  PlaybackState _playbackState;

  @override
  void initState() {
    super.initState();
    flutterSound = new FlutterSound();
    flutterSound.setSubscriptionDuration(0.01);
    flutterSound.setDbPeakLevelUpdate(0.8);
    flutterSound.setDbLevelEnabled(true);
    initializeDateFormatting();

    flutterSound.initialize(
      skipForwardHandler: () {
        print("Skip forward successfully called!");
      },
      skipBackwardForward: () {
        print("Skip backward successfully called!");
      },
    ).then((_) {
      print('media player initialization successful');
      setState(() {
        _canDisplayPlayerControls = true;
      });
    }).catchError((_) {
      print('media player initialization unsuccessful');
    });
  }

  @override
  void dispose() {
    super.dispose();

    if (_playerSubscription != null) {
      _playerSubscription.cancel();
      _playerSubscription = null;
    }

    if (_playbackStateSubscription != null) {
      _playbackStateSubscription.cancel();
      _playbackStateSubscription = null;
    }

    flutterSound.releaseMediaPlayer();
  }

  static const List<String> paths = [
    'sound.aac', // DEFAULT
    'sound.aac', // CODEC_AAC
    'sound.opus', // CODEC_OPUS
    'sound.caf', // CODEC_CAF_OPUS
    'sound.mp3', // CODEC_MP3
    'sound.ogg', // CODEC_VORBIS
    'sound.wav', // CODEC_PCM
  ];
  void startRecorder() async {
    try {
      // String path = await flutterSound.startRecorder
      // (
      //   paths[_codec.index],
      //   codec: _codec,
      //   sampleRate: 16000,
      //   bitRate: 16000,
      //   numChannels: 1,
      //   androidAudioSource: AndroidAudioSource.MIC,
      // );
      String path = await flutterSound.startRecorder( codec: _codec, );
      print('startRecorder: $path');

      flutterSound.onRecordingStateChanged.listen((newState) {
        print('This is the new recording state: $newState');
      });

      _recorderSubscription = flutterSound.onRecorderStateChanged.listen((e) {
        DateTime date = new DateTime.fromMillisecondsSinceEpoch(
            e.currentPosition.toInt(),
            isUtc: true);
        String txt = DateFormat('mm:ss:SS', 'en_GB').format(date);

        this.setState(() {
          this._recorderTxt = txt.substring(0, 8);
        });
      });
      _dbPeakSubscription =
          flutterSound.onRecorderDbPeakChanged.listen((value) {
        print("got update -> $value");
        setState(() {
          this._dbLevel = value;
        });
      });

      this.setState(() {
        this._isRecording = true;
        this._path[_codec.index] = path;
      });
    } catch (err) {
      print('startRecorder error: $err');
      setState(() {
        this._isRecording = false;
      });
    }
  }

  void stopRecorder() async {
    try {
      String result = await flutterSound.stopRecorder();
      print('stopRecorder: $result');

      if (_recorderSubscription != null) {
        _recorderSubscription.cancel();
        _recorderSubscription = null;
      }
      if (_dbPeakSubscription != null) {
        _dbPeakSubscription.cancel();
        _dbPeakSubscription = null;
      }
    } catch (err) {
      print('stopRecorder error: $err');
    }
    this.setState(() {
      this._isRecording = false;
    });
  }

  Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  // In this simple example, we just load a file in memory.This is stupid but just for demonstation  of startPlayerFromBuffer()
  Future <Uint8List> makeBuffer(String path) async {
    try {
      if (!await fileExists(path)) return null;
      File file = File(path);
      file.openRead();
      var contents = await file.readAsBytes();
      print('The file is ${contents.length} bytes long.');
      return contents;
    } catch (e) {
      print(e);
      return null;
    }
  }

  List<String> assetSample = [
    'assets/samples/sample.aac',
    'assets/samples/sample.aac',
    'assets/samples/sample.opus',
    'assets/samples/sample.caf',
    'assets/samples/sample.mp3',
    'assets/samples/sample.ogg',
    'assets/samples/sample.wav',
  ];

  void _addListeners() {
    _playbackStateSubscription =
        flutterSound.onPlaybackStateChanged.listen((newState) {
      _playbackState = newState;
      print('The new playack state is: $newState');
    });

    _playerSubscription = flutterSound.onPlayerStateChanged.listen((e) {
      if (e != null) {
        sliderCurrentPosition = e.currentPosition;
        maxDuration = e.duration;

        DateTime date = new DateTime.fromMillisecondsSinceEpoch(
            e.currentPosition.toInt(),
            isUtc: true);
        String txt = DateFormat('mm:ss:SS', 'en_GB').format(date);
        this.setState(() {
          //this._isPlaying = true;
          this._playerTxt = txt.substring(0, 8);
        });
      }
    });
  }

  void startPlayer() async {
    try {
      _addListeners();

      final exampleAudioFilePath =
          "https://file-examples.com/wp-content/uploads/2017/11/file_example_MP3_700KB.mp3";
      final albumArtPath =
          "https://file-examples.com/wp-content/uploads/2017/10/file_example_PNG_500kB.png";

      String path;
      Uint8List buffer;
      String audioFilePath;
      if (_media == t_MEDIA.ASSET) {
        buffer = (await rootBundle.load(assetSample[_codec.index]))
            .buffer
            .asUint8List();
      } else if (_media == t_MEDIA.FILE) {
        // Do we want to play from buffer or from file ?
        if (await fileExists(_path[_codec.index]))
          audioFilePath = this._path[_codec.index];
      } else if (_media == t_MEDIA.BUFFER) {
        // Do we want to play from buffer or from file ?
        if (await fileExists(_path[_codec.index])) {
          buffer = await makeBuffer(this._path[_codec.index]);
          if (buffer == null) {
            throw Exception('Unable to create the buffer');
          }
        }
      } else if (_media == t_MEDIA.REMOTE_EXAMPLE_FILE) {
        // We have to play an example audio file loaded via a URL
        audioFilePath = exampleAudioFilePath;
      }

      final track = Track(
        trackPath: audioFilePath,
        dataBuffer: buffer,
        codec: _codec,
        trackTitle: "Song Title",
        trackAuthor: "Song Author",
        albumArtUrl: albumArtPath,
      );
      path = await flutterSound.startPlayer(track, true, false);

      if (path == null) {
        print('Error starting player');
        return;
      }

      print('startPlayer: $path');
      // await flutterSound.setVolume(1.0);
    } catch (err) {
      print('error: $err');
    }
    setState(() {});
  }

  void stopPlayer() async {
    try {
      String result = await flutterSound.stopPlayer();
      print('stopPlayer: $result');
      sliderCurrentPosition = 0.0;
    } catch (err) {
      print('error: $err');
    }
    this.setState(() {
      //this._isPlaying = false;
    });
  }

  void pausePlayer() async {
    String result = await flutterSound.pausePlayer();
    print('pausePlayer: $result');
  }

  void resumePlayer() async {
    String result = await flutterSound.resumePlayer();
    print('resumePlayer: $result');
  }

  void seekToPlayer(int milliSecs) async {
    String result = await flutterSound.seekToPlayer(milliSecs);
    print('seekToPlayer: $result');
  }

  Widget makeDropdowns(BuildContext context) {
    final mediaDropdown = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Text('Media:'),
        ),
        DropdownButton<t_MEDIA>(
          value: _media,
          onChanged: (newMedia) {
            setState(() {
              _media = newMedia;
            });
          },
          items: <DropdownMenuItem<t_MEDIA>>[
            DropdownMenuItem<t_MEDIA>(
              value: t_MEDIA.FILE,
              child: Text('File'),
            ),
            DropdownMenuItem<t_MEDIA>(
              value: t_MEDIA.BUFFER,
              child: Text('Buffer'),
            ),
            DropdownMenuItem<t_MEDIA>(
              value: t_MEDIA.ASSET,
              child: Text('Asset'),
            ),
            DropdownMenuItem<t_MEDIA>(
              value: t_MEDIA.REMOTE_EXAMPLE_FILE,
              child: Text('Remote Example File'),
            ),
          ],
        ),
      ],
    );

    final codecDropdown = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Text('Codec:'),
        ),
        DropdownButton<t_CODEC>(
          value: _codec,
          onChanged: _media == t_MEDIA.REMOTE_EXAMPLE_FILE
              ? null
              : (newCodec) {
                  setState(() {
                    _codec = newCodec;
                  });
                },
          items: <DropdownMenuItem<t_CODEC>>[
            DropdownMenuItem<t_CODEC>(
              value: t_CODEC.CODEC_AAC,
              child: Text('AAC'),
            ),
            DropdownMenuItem<t_CODEC>(
              value: t_CODEC.CODEC_OPUS,
              child: Text('OGG/Opus'),
            ),
            DropdownMenuItem<t_CODEC>(
              value: t_CODEC.CODEC_CAF_OPUS,
              child: Text('CAF/Opus'),
            ),
            DropdownMenuItem<t_CODEC>(
              value: t_CODEC.CODEC_MP3,
              child: Text('MP3'),
            ),
            DropdownMenuItem<t_CODEC>(
              value: t_CODEC.CODEC_VORBIS,
              child: Text('OGG/Vorbis'),
            ),
            DropdownMenuItem<t_CODEC>(
              value: t_CODEC.CODEC_PCM,
              child: Text('PCM'),
            ),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: mediaDropdown,
          ),
          codecDropdown,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recorderProgressIndicator = _isRecording
        ? LinearProgressIndicator(
            value: 100.0 / 160.0 * (this._dbLevel ?? 1) / 100,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            backgroundColor: Colors.red,
          )
        : Container();
    final recorderSection = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          margin: EdgeInsets.only(top: 24.0, bottom: 16.0),
          child: Text(
            this._recorderTxt,
            style: TextStyle(
              fontSize: 48.0,
              color: Colors.black,
            ),
          ),
        ),
        recorderProgressIndicator,
        Row(
          children: <Widget>[
            Container(
              width: 56.0,
              height: 56.0,
              child: ClipOval(
                child: FlatButton(
                  onPressed: () {
                    if (!this._isRecording) {
                      return this.startRecorder();
                    }
                    this.stopRecorder();
                  },
                  padding: EdgeInsets.all(8.0),
                  child: Image(
                    image: this._isRecording
                        ? AssetImage('res/icons/ic_stop.png')
                        : AssetImage('res/icons/ic_mic.png'),
                  ),
                ),
              ),
            ),
          ],
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
      ],
    );

    final playerControls = !_canDisplayPlayerControls
        ? Container(child: Container(child: CircularProgressIndicator()))
        : Row(
            children: <Widget>[
              Container(
                width: 56.0,
                height: 56.0,
                child: ClipOval(
                  child: FlatButton(
                    onPressed: () {
                      if (_playbackState == PlaybackState.PAUSED) {
                        resumePlayer();
                      } else {
                        startPlayer();
                      }
                    },
                    padding: EdgeInsets.all(8.0),
                    child: Image(
                      image: AssetImage('res/icons/ic_play.png'),
                    ),
                  ),
                ),
              ),
              Container(
                width: 56.0,
                height: 56.0,
                child: ClipOval(
                  child: FlatButton(
                    onPressed: () {
                      pausePlayer();
                    },
                    padding: EdgeInsets.all(8.0),
                    child: Image(
                      width: 36.0,
                      height: 36.0,
                      image: AssetImage('res/icons/ic_pause.png'),
                    ),
                  ),
                ),
              ),
              Container(
                width: 56.0,
                height: 56.0,
                child: ClipOval(
                  child: FlatButton(
                    onPressed: () {
                      stopPlayer();
                    },
                    padding: EdgeInsets.all(8.0),
                    child: Image(
                      width: 28.0,
                      height: 28.0,
                      image: AssetImage('res/icons/ic_stop.png'),
                    ),
                  ),
                ),
              ),
              Container(
                width: 56.0,
                height: 56.0,
                child: IconButton(
                  icon: Icon(Icons.bug_report),
                  onPressed: () async {
                    await flutterSound.releaseMediaPlayer();
                    await flutterSound.initialize();
                    print('player initialized');
                  },
                ),
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
          );
    final playerSlider = Container(
        height: 56.0,
        child: Slider(
            value: sliderCurrentPosition,
            min: 0.0,
            max: maxDuration,
            onChanged: (double value) async {
              await flutterSound.seekToPlayer(value.toInt());
            },
            divisions: maxDuration.toInt()));
    final playerSection = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          margin: EdgeInsets.only(top: 60.0, bottom: 16.0),
          child: Text(
            this._playerTxt,
            style: TextStyle(
              fontSize: 48.0,
              color: Colors.black,
            ),
          ),
        ),
        playerControls,
        playerSlider,
      ],
    );

    final dropdowns = makeDropdowns(context);

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Sound'),
        ),
        body: ListView(
          children: <Widget>[
            recorderSection,
            playerSection,
            dropdowns,
          ],
        ),
      ),
    );
  }
}
