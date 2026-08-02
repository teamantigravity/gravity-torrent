import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
void main() {
  final player = Player();
  final controller = VideoController(player);
  print(controller is Object);
}
