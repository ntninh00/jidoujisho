import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:network_to_file_image/network_to_file_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yuuna/creator.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/utils.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

/// An enhancement used effectively as a shortcut for clearing the contents
/// of a [CreatorModel] pertaining to a certain field.
class BingImagesSearchEnhancement extends ImageEnhancement {
  /// Initialise this enhancement with the hardset parameters.
  BingImagesSearchEnhancement()
      : super(
          uniqueKey: key,
          label: 'Bing Images Search',
          description:
              'Search Bing for images with the current image query or the word.',
          icon: Ui.image_search,
          field: ImageField.instance,
        );

  /// Used to identify this enhancement and to allow a constant value for the
  /// default mappings value of [AnkiMapping].
  static const String key = 'bing_images_search';

  /// The Bing Images page for [searchTerm].
  static Uri searchUri(String searchTerm) {
    return Uri.https('www.bing.com', '/images/search', {'q': searchTerm});
  }

  /// The image addresses in a Bing Images results page, in order. Results
  /// without one are skipped.
  static List<String> parseImageUrls(String? html) {
    dom.Document document = parser.parse(html ?? '');
    List<String> urls = [];
    for (dom.Element element in document.getElementsByClassName('iusc')) {
      try {
        Object? data = jsonDecode(element.attributes['m'] ?? '');
        Object? url = data is Map ? data['turl'] : null;
        if (url is String && url.isNotEmpty) {
          urls.add(url);
        }
      } catch (_) {
        continue;
      }
    }
    return urls;
  }

  /// Used to store results that have already been found at runtime.
  final Map<String, List<NetworkToFileImage>> _bingCache = {};

  @override
  Future<void> enhanceCreatorParams({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
    required CreatorModel creatorModel,
    required EnhancementTriggerCause cause,
  }) async {
    ImageExportField imageField = field as ImageExportField;
    String? searchTerm;

    if (cause != EnhancementTriggerCause.auto) {
      searchTerm = imageField.getSearchTermWithFallback(
        appModel: appModel,
        creatorModel: creatorModel,
        fallbackSearchTerms: [TermField.instance],
      );
      if (searchTerm == null) {
        return;
      }
    } else {
      searchTerm = creatorModel.getFieldController(TermField.instance).text;

      if (searchTerm.trim().isEmpty) {
        return;
      }
    }

    await imageField.setImages(
      cause: cause,
      appModel: appModel,
      creatorModel: creatorModel,
      newAutoCannotOverride: false,
      searchTerm: searchTerm,
      generateImages: () async {
        return fetchImages(
          appModel: appModel,
          searchTerm: searchTerm,
        );
      },
    );
  }

  @override
  Future<List<NetworkToFileImage>> fetchImages({
    required AppModel appModel,
    String? searchTerm,
  }) async {
    if (_bingCache[searchTerm!] != null) {
      return _bingCache[searchTerm]!;
    }

    Completer<List<NetworkToFileImage>> found = Completer();
    bool reading = false;

    HeadlessInAppWebView webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(searchUri(searchTerm))),
        initialSettings: InAppWebViewSettings(blockNetworkImage: true),
        onLoadStop: (controller, uri) async {
          /// The page can finish loading more than once, as after a redirect.
          if (reading) {
            return;
          }
          reading = true;

          List<NetworkToFileImage> images = [];
          try {
            Directory appDirDoc = await getApplicationSupportDirectory();
            String bingImagesPath = '${appDirDoc.path}/bingImages';
            Directory bingImagesDir = Directory(bingImagesPath);
            if (bingImagesDir.existsSync()) {
              if (_bingCache.isEmpty) {
                bingImagesDir.deleteSync(recursive: true);
              }
            }
            bingImagesDir.createSync();

            await Future.delayed(const Duration(milliseconds: 1000), () {});

            List<String> imageURLs = parseImageUrls(await controller.getHtml());

            String timestamp =
                DateFormat('yyyyMMddTkkmmss').format(DateTime.now());
            Directory imageDir = Directory('$bingImagesPath/$timestamp');
            imageDir.createSync();
            for (int i = 0; i < imageURLs.length; i++) {
              String imagePath = '${imageDir.path}/$i';
              File imageFile = File(imagePath);

              /// Instant export requires a file to already be written to the
              /// file system.
              if (i == 0) {
                File networkFile =
                    await DefaultCacheManager().getSingleFile(imageURLs[i]);
                networkFile.copySync(imagePath);
              }
              NetworkToFileImage image = NetworkToFileImage(
                url: imageURLs[i],
                file: imageFile,
              );

              images.add(image);
            }
          } catch (error) {
            debugPrint('Bing image search failed: $error');
            images = [];
          } finally {
            if (!found.isCompleted) {
              found.complete(images);
            }
          }
        });

    List<NetworkToFileImage> images = [];
    try {
      await webView.run();

      /// If Bing doesn't answer, the search ends with no images instead of
      /// loading forever.
      images = await found.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => [],
      );
    } catch (error) {
      debugPrint('Bing image search failed: $error');
    } finally {
      await webView.dispose();
    }

    if (images.isNotEmpty) {
      _bingCache[searchTerm] = images;
    }

    return images;
  }
}
