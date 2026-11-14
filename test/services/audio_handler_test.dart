import 'dart:io';

import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/services/audio_handler.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late VideoPlayerServiceHandler handler;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('piliplus_audio_test_');
    Hive.init(temp.path);
    GStorage.setting = await Hive.openBox('setting');
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    handler = VideoPlayerServiceHandler();
    handler.onVideoDetailChange(
      VideoDetailData(title: 'Video', duration: 120),
      1,
      ':video',
    );
    handler
      ..onPlay = () async {}
      ..onSkipToPrevious = () {}
      ..onSkipToNext = () {};
    handler.onVideoDetailChange(
      VideoDetailData(title: 'Audio', duration: 120),
      2,
      ':audio',
      isAudioPlayer: true,
    );
  });
  tearDown(() {
    handler.clear();
    debugDefaultTargetPlatformOverride = null;
  });

  void update(PlayerStatus status, {bool buffering = false, int ms = 10000}) {
    handler.onUpdateState(
      status,
      buffering,
      false,
      position: Duration(milliseconds: ms),
      speed: 1.5,
      isAudioPlayer: true,
    );
  }

  test('iOS audio exposes track commands and dispatches both callbacks', () async {
    var previous = 0;
    var next = 0;
    handler
      ..onSkipToPrevious = () => previous++
      ..onSkipToNext = () => next++;
    update(PlayerStatus.playing);
    expect(handler.playbackState.value.controls.map((c) => c.action), [
      MediaAction.skipToPrevious,
      MediaAction.pause,
      MediaAction.skipToNext,
    ]);
    await handler.skipToPrevious();
    await handler.skipToNext();
    expect(previous, 1);
    expect(next, 1);
  });

  test('video events and metadata cannot overwrite the audio owner', () {
    update(PlayerStatus.playing);
    handler.onUpdateState(
      PlayerStatus.paused,
      false,
      false,
      position: Duration.zero,
      speed: 1,
    );
    handler.onVideoDetailChange(VideoDetailData(title: 'Stale'), 3, ':video');
    handler.onVideoDetailDispose(':video');
    expect(handler.playbackState.value.playing, isTrue);
    expect(handler.mediaItem.value?.title, 'Audio');
  });

  test('paused buffering stays paused and buffering stops the iOS clock', () {
    update(PlayerStatus.playing, buffering: true);
    expect(handler.playbackState.value.playing, isTrue);
    expect(handler.playbackState.value.speed, 0);
    update(PlayerStatus.paused, buffering: true);
    expect(handler.playbackState.value.playing, isFalse);
    update(PlayerStatus.playing);
    expect(handler.playbackState.value.speed, 1.5);
    expect(handler.playbackState.value.processingState, AudioProcessingState.ready);
  });

  test('subsecond seeks and completion are published', () {
    update(PlayerStatus.paused, ms: 10100);
    update(PlayerStatus.paused, ms: 10900);
    expect(handler.playbackState.value.updatePosition.inMilliseconds, 10900);
    update(PlayerStatus.completed);
    expect(handler.playbackState.value.processingState, AudioProcessingState.completed);
    expect(handler.playbackState.value.playing, isFalse);
  });

  test('duration follows the decoder and repeated tracks do not resurrect', () {
    handler.updateDuration(const Duration(seconds: 42), ':audio');
    expect(handler.mediaItem.value?.duration, const Duration(seconds: 42));
    handler.onVideoDetailChange(
      VideoDetailData(title: 'Next'),
      4,
      ':audio',
      isAudioPlayer: true,
    );
    handler.onPlay = null;
    handler.onVideoDetailDispose(':audio');
    expect(handler.mediaItem.value?.title, 'Video');
    handler.onVideoDetailDispose(':video');
    handler.clearIfNeeded();
    expect(handler.mediaItem.value, isNull);
    expect(handler.playbackState.value.processingState, AudioProcessingState.idle);
  });

  test('Android retains seek buttons', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    update(PlayerStatus.playing);
    expect(handler.playbackState.value.controls.map((c) => c.action), [
      MediaAction.rewind,
      MediaAction.pause,
      MediaAction.fastForward,
    ]);
  });
}
