// Copyright 2019 The Sponge authors.
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
//
//
// The code in this file is a modified Flutter widget PopupMenuButton that adds support for an asynchronous item builder.
//
//
// The original license:
// "Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.""

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';

typedef AsyncPopupMenuItemBuilder<T> = FutureOr<List<PopupMenuEntry<T>>>
    Function(BuildContext context);

class AsyncPopupMenuButton<T> extends StatefulWidget {
  /// Creates a button that shows a popup menu.
  ///
  /// The [itemBuilder] argument must not be null.
  /// Creates a button that shows a popup menu.
  ///
  /// The [itemBuilder] argument must not be null.
  const AsyncPopupMenuButton({
    Key key,
    @required this.itemBuilder,
    this.initialValue,
    this.onSelected,
    this.onCanceled,
    this.tooltip,
    this.elevation,
    this.padding = const EdgeInsets.all(8.0),
    this.child,
    this.icon,
    this.offset = Offset.zero,
    this.enabled = true,
    this.shape,
    this.color,
    this.captureInheritedThemes = true,
  })  : assert(itemBuilder != null),
        assert(offset != null),
        assert(enabled != null),
        assert(captureInheritedThemes != null),
        assert(!(child != null && icon != null),
            'You can only pass [child] or [icon], not both.'),
        super(key: key);

  /// Called when the button is pressed to create the items to show in the menu.
  final AsyncPopupMenuItemBuilder<T> itemBuilder;

  /// The value of the menu item, if any, that should be highlighted when the menu opens.
  final T initialValue;

  /// Called when the user selects a value from the popup menu created by this button.
  ///
  /// If the popup menu is dismissed without selecting a value, [onCanceled] is
  /// called instead.
  final PopupMenuItemSelected<T> onSelected;

  /// Called when the user dismisses the popup menu without selecting an item.
  ///
  /// If the user selects a value, [onSelected] is called instead.
  final PopupMenuCanceled onCanceled;

  /// Text that describes the action that will occur when the button is pressed.
  ///
  /// This text is displayed when the user long-presses on the button and is
  /// used for accessibility.
  final String tooltip;

  /// The z-coordinate at which to place the menu when open. This controls the
  /// size of the shadow below the menu.
  ///
  /// Defaults to 8, the appropriate elevation for popup menus.
  final double elevation;

  /// Matches IconButton's 8 dps padding by default. In some cases, notably where
  /// this button appears as the trailing element of a list item, it's useful to be able
  /// to set the padding to zero.
  final EdgeInsetsGeometry padding;

  /// If provided, [child] is the widget used for this button
  /// and the button will utilize an [InkWell] for taps.
  final Widget child;

  /// If provided, the [icon] is used for this button
  /// and the button will behave like an [IconButton].
  final Widget icon;

  /// The offset applied to the Popup Menu Button.
  ///
  /// When not set, the Popup Menu Button will be positioned directly next to
  /// the button that was used to create it.
  final Offset offset;

  /// Whether this popup menu button is interactive.
  ///
  /// Must be non-null, defaults to `true`
  ///
  /// If `true` the button will respond to presses by displaying the menu.
  ///
  /// If `false`, the button is styled with the disabled color from the
  /// current [Theme] and will not respond to presses or show the popup
  /// menu and [onSelected], [onCanceled] and [itemBuilder] will not be called.
  ///
  /// This can be useful in situations where the app needs to show the button,
  /// but doesn't currently have anything to show in the menu.
  final bool enabled;

  /// If provided, the shape used for the menu.
  ///
  /// If this property is null, then [PopupMenuThemeData.shape] is used.
  /// If [PopupMenuThemeData.shape] is also null, then the default shape for
  /// [MaterialType.card] is used. This default shape is a rectangle with
  /// rounded edges of BorderRadius.circular(2.0).
  final ShapeBorder shape;

  /// If provided, the background color used for the menu.
  ///
  /// If this property is null, then [PopupMenuThemeData.color] is used.
  /// If [PopupMenuThemeData.color] is also null, then
  /// Theme.of(context).cardColor is used.
  final Color color;

  /// If true (the default) then the menu will be wrapped with copies
  /// of the [InheritedThemes], like [Theme] and [PopupMenuTheme], which
  /// are defined above the [BuildContext] where the menu is shown.
  final bool captureInheritedThemes;

  @override
  _AsyncPopupMenuButton<T> createState() => _AsyncPopupMenuButton<T>();
}

class _AsyncPopupMenuButton<T> extends State<AsyncPopupMenuButton<T>> {
  bool _fetchingData = false;

  Future<void> showButtonMenu() async {
    setState(() => _fetchingData = true);

    try {
      final PopupMenuThemeData popupMenuTheme = PopupMenuTheme.of(context);
      final RenderBox button = context.findRenderObject();
      final RenderBox overlay = Overlay.of(context).context.findRenderObject();
      final RelativeRect position = RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(widget.offset, ancestor: overlay),
          button.localToGlobal(button.size.bottomRight(Offset.zero),
              ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      );
      final List<PopupMenuEntry<T>> items = await widget.itemBuilder(context);
      // Only show the menu if there is something to show
      if (items.isNotEmpty) {
        T newValue = await showMenu<T>(
          context: context,
          elevation: widget.elevation ?? popupMenuTheme.elevation,
          items: items,
          initialValue: widget.initialValue,
          position: position,
          shape: widget.shape ?? popupMenuTheme.shape,
          color: widget.color ?? popupMenuTheme.color,
          captureInheritedThemes: widget.captureInheritedThemes,
        );

        if (!mounted) return null;
        if (newValue == null) {
          if (widget.onCanceled != null) widget.onCanceled();
          return null;
        }
        if (widget.onSelected != null) widget.onSelected(newValue);
      }
    } finally {
      setState(() => _fetchingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));

    if (widget.child != null) {
      return Tooltip(
        message:
            widget.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
        child: InkWell(
          onTap: widget.enabled && !_fetchingData ? showButtonMenu : null,
          canRequestFocus: widget.enabled,
          child: widget.child,
        ),
      );
    }

    return IconButton(
      icon: widget.icon ?? getPopupMenuIcon(context),
      padding: widget.padding,
      tooltip:
          widget.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
      onPressed: widget.enabled && !_fetchingData ? showButtonMenu : null,
    );
  }
}
