/// The files of `protocol-v1.md` §6 both ends agree on.
abstract final class FileSizes {
  /// The one thumbnail a master keeps of an image, in pixels wide: `GET /f/<id>?size=320`. A
  /// smaller size gets it too; a larger one, the original.
  static const thumbnail = 320;
}
