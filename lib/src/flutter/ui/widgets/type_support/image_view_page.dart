// Copyright 2020 The Sponge authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';

typedef OnFileSaveCallback = Future<String> Function();

class ImageViewPage extends StatelessWidget {
  ImageViewPage({
    Key key,
    @required this.name,
    @required this.imageData,
    @required this.onSave,
  }) : super(key: key);

  final String name;
  final Uint8List imageData;
  final OnFileSaveCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          appBar: MediaQuery.of(context).orientation == Orientation.portrait
              ? AppBar(
                  title: Text('${name ?? ''}'),
                  actions: <Widget>[
                    PopupMenuButton<String>(
                      key: Key('actions'),
                      onSelected: (value) async {
                        switch (value) {
                          case 'save':
                            var filePath = await onSave();
                            await showModalDialog(
                                context,
                                'Information',
                                Text(
                                    'The image has been saved to the file $filePath'));
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                            key: Key('save'),
                            value: 'save',
                            child: Text('Save to a file...')),
                      ],
                    )
                  ],
                )
              : null,
          body: Container(
            child: PhotoView(
              imageProvider: MemoryImage(imageData),
              backgroundDecoration: BoxDecoration(),
            ),
          ),
        ),
      ),
    );
  }
}
