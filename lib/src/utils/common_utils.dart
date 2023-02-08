import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:full_picker/src/sheets/voice_recorder_sheet.dart';
import 'package:full_picker/src/utils/border_radius_m3.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:light_compressor/light_compressor.dart';
import '../../full_picker.dart';
import '../dialogs/url_input_dialog.dart';

/// show top sheet title and back button
topSheet(String title, BuildContext context) {
  return Column(children: [
    // Drag handle
    Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(40),
          borderRadius: const BorderRadius.all(Radius.circular(30)),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.only(top: 2, left: 5),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ]);
}

/// show sheet
void showSheet(Widget widget, BuildContext context,
    {bool isDismissible = true}) {
  showModalBottomSheet(
      context: context,
      isDismissible: isDismissible,
      shape: RoundedRectangleBorder(
          borderRadius: Theme.of(context).useMaterial3
              ? BorderRadiusM3.extraLargeTop
              : BorderRadius.zero),
      builder: (BuildContext context) {
        return widget;
      });
}

FileType extensionType(String extension) {
  if (extension == "") {
    return FileType.any;
  } else if (extension == 'aac' ||
      extension == 'midi' ||
      extension == "mp3" ||
      extension == "ogg" ||
      extension == "wav") {
    return FileType.audio;
  } else if (extension == 'bmp' ||
      extension == 'gif' ||
      extension == "jpeg" ||
      extension == "jpg" ||
      extension == "png") {
    return FileType.image;
  } else if (extension == 'avi' ||
      extension == 'flv' ||
      extension == "mkv" ||
      extension == "mov" ||
      extension == "mp4" ||
      extension == 'mpeg' ||
      extension == 'webm' ||
      extension == "wmv") {
    return FileType.video;
  } else {
    return FileType.any;
  }
}

/// get files
Future<FullPickerOutput?> getFiles(
    {required BuildContext context,
    required FileType fileType,
    required FullPickerType pickerFileType,
    required String prefixName,
    required ValueSetter<bool> onIsUserCheng,
    required ValueSetter<int>? onError,
    List<String>? allowedExtensions,
    bool videoCompressor = false,
    required bool inSheet,
    bool imageCropper = false,
    bool multiFile = false}) async {
  ProgressIndicatorDialog progressDialog = ProgressIndicatorDialog(context);

  FilePickerResult? result = await FilePicker.platform
      .pickFiles(
    allowMultiple: multiFile,
    type: fileType,
    allowedExtensions: allowedExtensions,
    onFileLoading: (value) {
      if (value == FilePickerStatus.picking) {
        progressDialog.show();
      } else {
        return null;
      }
    },
  )
      .catchError((error, stackTrace) {
    showFullPickerToast(globalLanguage.denyAccessPermission, context);
    return null;
  });

  if (result != null) {
    progressDialog.dismiss();
    List<File?> files = [];
    List<String?> name = [];
    List<Uint8List?> bytes = [];

    int numberVideo = 0;
    int numberPicture = 0;
    for (final file in result.files) {
      name.add("${prefixName}_${name.length + 1}.${file.extension!}");
      Uint8List byte;

      if (file.bytes == null) {
        byte = File(file.path!).readAsBytesSync();
      } else {
        byte = file.bytes!;
      }

      if (!isWeb) {
        if (file.path != null) {
          files.add(File(file.path!));
        }
      }

      // for counter
      if (extensionType(file.extension!) == FileType.video) {
        numberVideo = numberVideo + 1;
      }

      if (extensionType(file.extension!) == FileType.image) {
        numberPicture = numberPicture + 1;
      }

      /// video compressor
      if (file.extension == "mp4" && videoCompressor) {
        Uint8List? byteCompress =
            await videoCompress(context: context, byte: byte, file: file);

        if (byteCompress == null) return null;

        byte = byteCompress;
      }

      /// image cropper
      if (file.extension == "jpg" && imageCropper) {
        try {
          Uint8List? byteCrop =
              await cropImage(context: context, byte: byte, file: file);

          if (byteCrop == null) return null;

          byte = byteCrop;
        } catch (_) {}
      }

      bytes.add(byte);
    }
    if (pickerFileType == FullPickerType.mixed) {
      if (numberPicture == 0 && numberVideo != 0) {
        return FullPickerOutput(bytes, FullPickerType.video, name, files);
      } else if (numberPicture != 0 && numberVideo == 0) {
        return FullPickerOutput(
            bytes, FullPickerType.image, [name.first], files);
      } else {
        // mixed
        return FullPickerOutput(bytes, pickerFileType, name, files);
      }
    } else {
      return FullPickerOutput(bytes, pickerFileType, name, files);
    }
  } else {
    return null;
  }
}

clearTempFiles() async {
  try {
    await FilePicker.platform.clearTemporaryFiles();
  } catch (_) {}
}

/// re director for select file
/// 1 = Gallery
/// 2 = Camera
/// 3 = File
void getFullPicker({
  required id,
  required context,
  required ValueSetter<bool> onIsUserCheng,
  required ValueSetter<FullPickerOutput> onSelected,
  required ValueSetter<int>? onError,
  required bool image,
  required bool video,
  required bool file,
  required bool voiceRecorder,
  required bool url,
  required String bodyTextUrl,
  required bool imageCamera,
  required bool videoCamera,
  required bool videoCompressor,
  required bool imageCropper,
  required bool multiFile,
  required String prefixName,
  required bool inSheet,
  required List<String>? allowedExtensions,
}) async {
  onIsUserCheng.call(false);
  FullPickerOutput? value;

  if (id == 1) {
    /// gallery

    if (image && video) {
      value = await getFiles(
          context: context,
          videoCompressor: videoCompressor,
          fileType: FileType.custom,
          pickerFileType: FullPickerType.mixed,
          prefixName: prefixName,
          inSheet: inSheet,
          allowedExtensions: allowedExtensions ??
              ["mp4", "avi", "mkv", "jpg", "jpeg", "png", "bmp"],
          multiFile: multiFile,
          onError: onError,
          imageCropper: imageCropper,
          onIsUserCheng: onIsUserCheng);
    } else if (image) {
      value = await getFiles(
          context: context,
          videoCompressor: videoCompressor,
          fileType: FileType.image,
          pickerFileType: FullPickerType.image,
          prefixName: prefixName,
          multiFile: multiFile,
          inSheet: inSheet,
          imageCropper: imageCropper,
          onError: onError,
          onIsUserCheng: onIsUserCheng);
    } else if (video) {
      value = await getFiles(
          context: context,
          videoCompressor: videoCompressor,
          fileType: FileType.video,
          pickerFileType: FullPickerType.video,
          prefixName: prefixName,
          imageCropper: imageCropper,
          inSheet: inSheet,
          multiFile: multiFile,
          onError: onError,
          onIsUserCheng: onIsUserCheng);
    }

    if (value == null) {
      checkError(inSheet, onIsUserCheng, context, isSelected: false);
      onError?.call(1);
    } else {
      checkError(inSheet, onIsUserCheng, context, isSelected: true);
      if (value.name.isNotEmpty) onSelected.call(value);
    }
  } else if (id == 2) {
    /// camera
    dynamic value = await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) {
        return Camera(
          imageCamera: imageCamera,
          videoCamera: videoCamera,
          prefixName: prefixName,
        );
      },
    ));

    if (value == 1 || value == null) {
      // Error
      checkError(inSheet, onIsUserCheng, context, isSelected: false);
      onError?.call(1);
    } else {
      checkError(inSheet, onIsUserCheng, context, isSelected: true);
      onSelected.call(value);
    }
  } else if (id == 3) {
    // File
    value = await getFiles(
        context: context,
        fileType: FileType.any,
        pickerFileType: FullPickerType.file,
        prefixName: prefixName,
        multiFile: multiFile,
        inSheet: inSheet,
        onError: onError,
        onIsUserCheng: onIsUserCheng);

    if (value == null) {
      checkError(inSheet, onIsUserCheng, context, isSelected: false);
      onError?.call(1);
    } else {
      checkError(inSheet, onIsUserCheng, context, isSelected: true);
      onSelected.call(value);
    }
  } else if (id == 4) {
    // Voice Recorder and isDismissible is false because recording may be closed unintentionally!
    showSheet(
        VoiceRecorderSheet(
            context: context,
            voiceFileName: "${prefixName}_1.m4a",
            onSelected: (value) {
              checkError(inSheet, onIsUserCheng, context, isSelected: true);
              onSelected.call(value);
              Navigator.of(context).pop();
            },
            onError: (value) {
              checkError(inSheet, onIsUserCheng, context, isSelected: true);
              onError?.call(1);
            }),
        context,
        isDismissible: false);
  } else if (id == 5) {
    // get url from URLInputDialog and convert to FullOutput
    String? url = await showDialog(
        context: context,
        builder: (context) => URLInputDialog(body: bodyTextUrl));

    if (url != null) {
      checkError(inSheet, onIsUserCheng, context, isSelected: true);
      onSelected.call(FullPickerOutput.data(url, FullPickerType.url));
    } else {
      checkError(inSheet, onIsUserCheng, context, isSelected: true);
      onError?.call(1);
    }
  }
}

/// check for control close sheet
checkError(inSheet, onIsUserCheng, context, {required bool isSelected}) {
  if (inSheet) {
    onIsUserCheng.call(false);

    if (isWeb) {
      if (isSelected) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    } else {
      if (Platform.isAndroid || Platform.isIOS) {
        Navigator.of(context).pop();
      } else {
        if (isSelected == false) Navigator.of(context).pop();
      }
    }
  }
}

/// web does not support video compression
/// video compressor
Future<Uint8List?> videoCompress({
  required context,
  required Uint8List byte,
  required PlatformFile file,
}) async {
  if (isWeb) {
    return byte;
  }

  File mainFile = File(file.path!);
  ValueNotifier<double> onProgress = ValueNotifier<double>(0);
  final LightCompressor lightCompressor = LightCompressor();

  int size = int.parse(File(mainFile.path).lengthSync().toString());
  if (size < 10000000) {
    return byte;
  }

  PercentProgressDialog progressDialog =
      PercentProgressDialog(context, (dynamic) {
    if (onProgress.value.toString() != "1.0") {
      LightCompressor.cancelCompression();
    }
  }, onProgress, globalLanguage.onCompressing);

  LightCompressor().onProgressUpdated.listen((event) {
    onProgress.value = event / 100;
  });

  try {
    progressDialog.show();
    final dynamic response = await lightCompressor.compressVideo(
      path: mainFile.path,
      videoQuality: VideoQuality.medium,
      android: AndroidConfig(isSharedStorage: false),
      ios: IOSConfig(saveInGallery: false),
      video: Video(
          videoName: '${DateTime.now().millisecondsSinceEpoch}."mp4"',
          videoBitrateInMbps: 24),
    );

    progressDialog.dismiss();

    if (response is OnSuccess) {
      File outputFile = File(response.destinationPath);
      Uint8List outputByte = outputFile.readAsBytesSync();

      /// delete cash file
      await outputFile.delete();
      return outputByte;
    } else if (response is OnFailure) {
      /// failure message
      return byte;
    } else if (response is OnCancelled) {
      return null;
    }
  } catch (e) {
    return byte;
  }

  return byte;
}

/// web does not support crop Image
/// crop image
Future<Uint8List?> cropImage({
  required context,
  required Uint8List byte,
  required PlatformFile file,
}) async {
  if (isWeb) {
    return byte;
  }

  CroppedFile? croppedFile = await ImageCropper().cropImage(
    sourcePath: file.path!,
    compressQuality: 20,
    aspectRatioPresets: Platform.isAndroid
        ? [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9
          ]
        : [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio5x3,
            CropAspectRatioPreset.ratio5x4,
            CropAspectRatioPreset.ratio7x5,
            CropAspectRatioPreset.ratio16x9
          ],
    uiSettings: [
      AndroidUiSettings(
          toolbarTitle: globalLanguage.cropper,
          toolbarColor: Theme.of(context).colorScheme.secondary,
          toolbarWidgetColor: Theme.of(context).colorScheme.primary,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false),
      IOSUiSettings(
        title: globalLanguage.cropper,
      )
    ],
  );

  try {
    return await croppedFile!.readAsBytes();
  } catch (e) {
    return null;
  }
}

/// show custom sheet
showFullPickerToast(String text, BuildContext context) {
  Widget toast = Container(
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25.0),
      color: const Color(0xFF656565),
    ),
    child: Text(text, style: const TextStyle(color: Color(0xfffefefe))),
  );

  FToast().init(context).showToast(
        child: toast,
        gravity: ToastGravity.BOTTOM,
      );
}
