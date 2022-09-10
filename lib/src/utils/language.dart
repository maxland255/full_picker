// language texts
class Language {
  String camera = "Camera";
  String selectFile = "Please select a file";
  String file = "File";
  String gallery = "Gallery";
  String cropper = "Photo cropping";
  String onCompressing = "Compressing...";
  String tapForPhotoHoldForVideo = "Tap for photo, hold for video";
  String cameraNotFound = "Camera not found !";
  String denyAccessPermission =
      "Unfortunately, you denied access, so it is not possible to use this part";

  Language();

  // help for cheng language texts
  Language.copy(
      {required this.camera,
      required this.file,
      required this.gallery,
      required this.cropper,
      required this.cameraNotFound,
      required this.denyAccessPermission,
      required this.onCompressing,
      required this.selectFile,
      required this.tapForPhotoHoldForVideo});
}
