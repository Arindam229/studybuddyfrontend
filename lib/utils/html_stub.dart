// stub for dart:html to prevent mobile build failures
class Window {
  Navigator get navigator => Navigator();
  Document get document => Document();
}

class Navigator {
  MediaDevices? get mediaDevices => null;
}

class MediaDevices {
  Future enumerateDevices() async => [];
  Future getUserMedia(Map constraints) async => throw UnimplementedError();
}

class Document {
  Element? getElementById(String id) => null;
  Body? get body => null;
}

class Element {
  void remove() {}
  void append(Element element) {}
}

class Body extends Element {}

class DivElement extends Element {
  String id = '';
  final style = Style();
}

class Style {
  String position = '';
  String top = '';
  String left = '';
  String width = '';
  String maxWidth = '';
  String height = '';
  String background = '';
  String display = '';
  String alignItems = '';
  String justifyContent = '';
  String zIndex = '';
  String padding = '';
  String borderRadius = '';
  String flexDirection = '';
  String marginTop = '';
  String border = '';
  String color = '';
}

class VideoElement extends Element {
  bool autoplay = false;
  void setAttribute(String name, String value) {}
  final style = Style();
  Object? srcObject;
}

class ButtonElement extends Element {
  String text = '';
  final style = Style();
  final onClick = ClickStream();
}

class ClickStream {
  void listen(void Function(dynamic) callback) {}
}

final window = Window();
final document = Document();
