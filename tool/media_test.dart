import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:media_kit/media_kit.dart';
Future<void> main() async {
 MediaKit.ensureInitialized(libmpv:File('build/windows/x64/runner/Release/libmpv-2.dll').absolute.path);
 final player=Player(configuration:const PlayerConfiguration(vo:'null'));
 await player.setVideoTrack(VideoTrack.auto());
 final errors=<String>[];final sub=player.stream.error.listen(errors.add);
 final report=<String,dynamic>{};
 for(final name in ['voice.wav','voice.opus','video.mp4']) {
  await player.setVolume(0);
  await player.open(Media(File('../demo/Family archive/$name').absolute.path));
  await Future<void>.delayed(const Duration(milliseconds:900));
  final advancing=player.state.position.inMilliseconds;
  await player.pause();await player.seek(const Duration(seconds:2));await player.setRate(1.5);
  await Future<void>.delayed(const Duration(milliseconds:300));
  report[name]={'durationMs':player.state.duration.inMilliseconds,'positionAdvancedMs':advancing,'seekMs':player.state.position.inMilliseconds,'rate':player.state.rate,'paused':!player.state.playing};
  stdout.writeln(report[name]);
  if(advancing<=0 || player.state.duration.inSeconds<3 || (player.state.position.inMilliseconds-2000).abs()>200) throw StateError('Playback validation failed for $name');
  await player.stop();
 }
 report['errors']=errors;report['scope']='Decoder, timeline advancement, pause, seek and speed; muted test, not a listening or rendered-video test.';
 stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
 File('build/media-test.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
 await sub.cancel();await player.dispose();
 if(errors.isNotEmpty) exitCode=1;
}

