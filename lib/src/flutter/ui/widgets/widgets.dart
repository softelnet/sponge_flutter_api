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

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class DefaultDrawerHeader extends StatelessWidget {
  DefaultDrawerHeader({
    Key key,
    @required this.applicationName,
  }) : assert(applicationName != null);

  final String applicationName;

  @override
  Widget build(BuildContext context) {
    return DrawerHeader(
      child: Column(
        children: [
          Image.asset('assets/images/logo.png', fit: BoxFit.scaleDown),
          Container(
            alignment: Alignment.centerRight,
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                return Text(
                    snapshot.hasData
                        ? '$applicationName, ver. ${snapshot.data.version}'
                        : '',
                    style: DefaultTextStyle.of(context)
                        .style
                        .apply(color: Colors.white)
                        .apply(fontSizeFactor: 1.2));
              },
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        color: isDarkTheme(context)
            ? Theme.of(context).dialogBackgroundColor
            : Theme.of(context).accentColor,
        image: DecorationImage(
            image: AssetImage('assets/images/banner.png'), fit: BoxFit.cover),
      ),
    );
  }
}

class IconTextPopupMenuItemWidget extends StatelessWidget {
  const IconTextPopupMenuItemWidget({
    Key key,
    @required this.icon,
    @required this.text,
    this.isOn,
  }) : super(key: key);

  final IconData icon;
  final String text;
  final bool isOn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Icon(
            icon,
            color: (isOn ?? true)
                ? getSecondaryColor(context)
                : getThemedBackgroundColor(context),
          ),
        ),
        Expanded(
          child: Text(text),
        ),
      ],
    );
  }
}

class SpinningWidget extends AnimatedWidget {
  const SpinningWidget({
    Key key,
    @required AnimationController controller,
    @required this.child,
  }) : super(key: key, listenable: controller);

  final Widget child;

  Animation<double> get _progress => listenable;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: _progress.value * 2.0 * math.pi,
        child: child,
      );
}

class ColoredTabBar extends StatelessWidget implements PreferredSizeWidget {
  ColoredTabBar({this.color, @required this.child});

  final Color color;
  final TabBar child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) => Container(
        color: color,
        child: child,
      );
}

typedef OnSwipePopCallback = void Function(BuildContext context);

class SwipeDetector extends StatefulWidget {
  SwipeDetector({
    Key key,
    @required this.child,
    this.onSwipe,
    this.ratio = 0.2,
  })  : assert(child != null),
        assert(ratio != null),
        super(key: key);

  final Widget child;
  final OnSwipePopCallback onSwipe;
  final double ratio;

  @override
  _SwipeDetectorState createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<SwipeDetector> {
  double dx = 0;

  @override
  Widget build(BuildContext context) {
    // Swipe disabled.
    if (widget.ratio == 0 || widget.onSwipe == null) {
      return widget.child;
    }

    return GestureDetector(
      child: widget.child,
      onPanStart: (details) => dx = 0,
      onPanUpdate: (details) {
        if (details.delta.dx > 0) {
          dx += details.delta.dx;

          var minDx = MediaQuery.of(context).size.width * widget.ratio;

          if (dx >= minDx) {
            widget.onSwipe(context);
          }
        } else if (details.delta.dx < 0) {
          dx = 0;
        }
      },
      onPanEnd: (details) {
        dx = 0;
      },
    );
  }
}

// This code is a copy from: https://github.com/flutter/flutter/blob/master/examples/flutter_gallery/lib/gallery/about.dart
class LinkTextSpan extends TextSpan {
  LinkTextSpan({TextStyle style, String url, String text})
      : super(
            style: style,
            text: text ?? url,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                launch(url, forceSafariVC: false);
              });
}

class OptionalScrollContainer extends InheritedWidget {
  OptionalScrollContainer({
    Key key,
    @required this.scrollable,
    @required Widget child,
  }) : super(key: key, child: child);

  final bool scrollable;

  @override
  bool updateShouldNotify(OptionalScrollContainer old) => true;

  static OptionalScrollContainer of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OptionalScrollContainer>();
}

class OptionalExpanded extends StatelessWidget {
  OptionalExpanded({
    Key key,
    @required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return (OptionalScrollContainer.of(context)?.scrollable ?? true)
        ? child
        : Expanded(child: child);
  }
}

class PageStorageConsumer extends StatelessWidget {
  PageStorageConsumer({
    Key key,
    @required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    var stateContainer = ApplicationProvider.of(context);

    return stateContainer != null
        ? PageStorage(
            bucket: stateContainer.bucket,
            key: stateContainer.storageKey,
            child: child,
          )
        : child;
  }
}
