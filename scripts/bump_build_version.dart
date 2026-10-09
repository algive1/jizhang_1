import 'dart:io';

// Reserve one version per APK build, including builds that later fail.
void main(List<String> args) {
  final file = File(
    args.isEmpty
        ? '${File.fromUri(Platform.script).parent.parent.path}/pubspec.yaml'
        : args.single,
  );
  final source = file.readAsStringSync();
  final pattern = RegExp(
    r'^version: (\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*\r?$',
    multiLine: true,
  );
  final current = pattern.firstMatch(source);
  if (current == null) {
    stderr.writeln('Expected version: major.minor.patch+build in ${file.path}');
    exit(1);
  }
  final patch = int.parse(current.group(3)!) + 1;
  final build = int.parse(current.group(4)!) + 1;
  final version = '${current.group(1)}.${current.group(2)}.$patch+$build';
  final ending = current.group(0)!.endsWith('\r') ? '\r' : '';
  file.writeAsStringSync(source.replaceFirst(pattern, 'version: $version$ending'));
  stdout.writeln(version);
}
