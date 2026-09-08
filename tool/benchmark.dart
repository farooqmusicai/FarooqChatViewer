import 'dart:convert';
import 'dart:io';
import 'package:farooq_chat_viewer/archive.dart';
Future<void> main() async {
 final root=Directory('build/synthetic-large');root.createSync(recursive:true);
 final chat=Directory('${root.path}/Synthetic 3.59 GB');chat.createSync();
 final buffer=StringBuffer();
 for(var i=0;i<25000;i++) {buffer.writeln('[13/06/2026, 14:${(i%60).toString().padLeft(2,'0')}:00] ${i%2==0?'Ali':'Sara'}: Synthetic message $i مرحبا hello');}
 final transcript=File('${chat.path}/_chat.txt')..writeAsStringSync(buffer.toString());
 final large=File('${chat.path}/synthetic-video.bin').openSync(mode:FileMode.write);
 large.truncateSync(3590000000-transcript.lengthSync());large.closeSync();
 final watch=Stopwatch()..start();final chats=await scanLibrary(root.absolute.path);final cold=watch.elapsedMilliseconds;
 watch.reset();final parsed=await parseTranscript(transcript.path);final parse=watch.elapsedMilliseconds;
 watch.reset();final matches=parsed.messages.where((m)=>m.text.contains('24999')).length;final search=watch.elapsedMicroseconds;
 final report={'fixture':'Synthetic logical-size file (not a playable 3.59 GB video)','bytes':chats.single.bytes,'messages':parsed.messages.length,'scanMs':cold,'parseMs':parse,'searchMicroseconds':search,'searchHits':matches,'rssBytes':ProcessInfo.currentRss,'maxRssBytes':ProcessInfo.maxRss,'os':Platform.operatingSystemVersion,'dart':Platform.version};
 stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
 File('build/benchmark.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
}

