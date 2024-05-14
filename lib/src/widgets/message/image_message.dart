import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages, implementation_imports
import 'package:flutter_cache_manager/src/cache_managers/default_cache_manager.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../conditional/conditional.dart';
import '../../util.dart';
import '../state/inherited_chat_theme.dart';
import '../state/inherited_user.dart';

/// A class that represents image message widget. Supports different
/// aspect ratios, renders blurred image as a background which is visible
/// if the image is narrow, renders image in form of a file if aspect
/// ratio is very small or very big.
class ImageMessage extends StatefulWidget {
  /// Creates an image message widget based on [types.ImageMessage].
  const ImageMessage({
    super.key,
    this.imageHeaders,
    this.imageProviderBuilder,
    required this.message,
    required this.messageWidth,
  });

  /// See [Chat.imageHeaders].
  final Map<String, String>? imageHeaders;

  /// See [Chat.imageProviderBuilder].
  final ImageProvider Function({
    required String uri,
    required Map<String, String>? imageHeaders,
    required Conditional conditional,
  })? imageProviderBuilder;

  /// [types.ImageMessage].
  final types.ImageMessage message;

  /// Maximum message width.
  final int messageWidth;

  @override
  State<ImageMessage> createState() => _ImageMessageState();
}

/// [ImageMessage] widget state.
class _ImageMessageState extends State<ImageMessage> {
  ImageProvider? _image;
  Size _size = Size.zero;
  ImageStream? _stream;

  @override
  void initState() {
    super.initState();
    _image = widget.imageProviderBuilder != null
        ? widget.imageProviderBuilder!(
            uri: widget.message.uri,
            imageHeaders: widget.imageHeaders,
            conditional: Conditional(),
          )
        : Conditional().getProvider(
            widget.message.uri,
            headers: widget.imageHeaders,
          );
    _size = Size(widget.message.width ?? 0, widget.message.height ?? 0);
  }

  Future<Uint8List?> _getPhotoBytes({
    required String url,
    Map<String, String>? headers,
  }) async {
    Uint8List? returnBytes;
    await DefaultCacheManager()
        .getSingleFile(url, headers: headers)
        .then((info) async {
      await info.readAsBytes().then((bytes) async {
        returnBytes = bytes;
      }).catchError((_) => null);
    }).catchError((_) => null);
    return returnBytes;
  }

  Widget _saveButton() => Positioned(
        top: 10,
        right: 10,
        child: GestureDetector(
          onTap: () async {
            final toastColor =
                InheritedChatTheme.of(context).theme.attachmentBadgeColor;
            final toastTextColor = InheritedChatTheme.of(context)
                .theme
                .attachmentBadgeTextStyle
                .color;
            // final configuration = createLocalImageConfiguration(context);
            await Fluttertoast.showToast(
              msg: 'Сохранено в галерею',
              backgroundColor: toastColor,
              textColor: toastTextColor,
              fontSize: 16.0,
              gravity: Platform.isIOS ? ToastGravity.TOP : ToastGravity.BOTTOM,
              toastLength: Toast.LENGTH_LONG,
            );
            await [Permission.storage].request();
            final photoBytes = await _getPhotoBytes(
              url: widget.message.uri,
              headers: widget.imageHeaders,
            );
            if (photoBytes != null) {
              await ImageGallerySaver.saveImage(
                photoBytes,
                quality: 99,
                name: widget.message.name,
              );
            }
          },
          child: InheritedChatTheme.of(context).theme.imageSaveIcon,
        ),
      );

  void _getImage() {
    final oldImageStream = _stream;
    _stream = _image?.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == oldImageStream?.key) {
      return;
    }
    final listener = ImageStreamListener(_updateImage);
    oldImageStream?.removeListener(listener);
    _stream?.addListener(listener);
  }

  void _updateImage(ImageInfo info, bool _) {
    setState(() {
      _size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_size.isEmpty) {
      _getImage();
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(ImageStreamListener(_updateImage));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = InheritedUser.of(context).user;

    if (_size.aspectRatio == 0) {
      return Container(
        color: InheritedChatTheme.of(context).theme.secondaryColor,
        height: _size.height,
        width: _size.width,
      );
    } else if (_size.aspectRatio < 0.1 || _size.aspectRatio > 10) {
      return Stack(
        children: [
          Container(
            color: user.id == widget.message.author.id
                ? InheritedChatTheme.of(context).theme.primaryColor
                : InheritedChatTheme.of(context).theme.secondaryColor,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 64,
                  margin: EdgeInsetsDirectional.fromSTEB(
                    InheritedChatTheme.of(context).theme.messageInsetsVertical,
                    InheritedChatTheme.of(context).theme.messageInsetsVertical,
                    16,
                    InheritedChatTheme.of(context).theme.messageInsetsVertical,
                  ),
                  width: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image(
                      fit: BoxFit.cover,
                      image: _image!,
                    ),
                  ),
                ),
                Flexible(
                  child: Container(
                    margin: EdgeInsetsDirectional.fromSTEB(
                      0,
                      InheritedChatTheme.of(context)
                          .theme
                          .messageInsetsVertical,
                      InheritedChatTheme.of(context)
                          .theme
                          .messageInsetsHorizontal,
                      InheritedChatTheme.of(context)
                          .theme
                          .messageInsetsVertical,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.message.name,
                          style: user.id == widget.message.author.id
                              ? InheritedChatTheme.of(context)
                                  .theme
                                  .sentMessageBodyTextStyle
                              : InheritedChatTheme.of(context)
                                  .theme
                                  .receivedMessageBodyTextStyle,
                          textWidthBasis: TextWidthBasis.longestLine,
                        ),
                        Container(
                          margin: const EdgeInsets.only(
                            top: 4,
                          ),
                          child: Text(
                            formatBytes(widget.message.size.truncate()),
                            style: user.id == widget.message.author.id
                                ? InheritedChatTheme.of(context)
                                    .theme
                                    .sentMessageCaptionTextStyle
                                : InheritedChatTheme.of(context)
                                    .theme
                                    .receivedMessageCaptionTextStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (InheritedChatTheme.of(context).theme.imageSaveIcon != null)
            _saveButton(),
        ],
      );
    } else {
      return Stack(
        children: [
          Container(
            constraints: BoxConstraints(
              maxHeight: widget.messageWidth.toDouble(),
              minWidth: 170,
            ),
            child: AspectRatio(
              aspectRatio: _size.aspectRatio > 0 ? _size.aspectRatio : 1,
              child: Image(
                fit: BoxFit.contain,
                image: _image!,
              ),
            ),
          ),
          if (InheritedChatTheme.of(context).theme.imageSaveIcon != null)
            _saveButton(),
        ],
      );
    }
  }
}
