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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';

class DateTimeEditWidget extends StatefulWidget {
  DateTimeEditWidget({
    Key key,
    @required this.name,
    @required this.initialValue,
    @required this.onValueChanged,
    this.enabled = true,
    this.firstDate,
    this.lastDate,
    this.yearsRange = 200,
  }) : super(key: key);

  final String name;
  final DateTime initialValue;
  final ValueChanged<DateTime> onValueChanged;
  final bool enabled;
  final DateTime firstDate;
  final DateTime lastDate;
  final int yearsRange;

  @override
  _DateTimeEditWidgetState createState() => _DateTimeEditWidgetState();
}

// TODO DateTime editor support for different dateTimeKind.
class _DateTimeEditWidgetState extends State<DateTimeEditWidget> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.name != null) Text(widget.name),
        FlatButton(
          child: Text(widget.initialValue != null
              ? DateFormat('yyyy-MM-dd').format(widget.initialValue)
              : 'DATE'),
          onPressed: () =>
              _showDatePicker().catchError((e) => handleError(context, e)),
        ),
        FlatButton(
          child: Text(widget.initialValue != null
              ? DateFormat('HH:mm').format(widget.initialValue)
              : 'TIME'),
          onPressed: () =>
              _showTimePicker().catchError((e) => handleError(context, e)),
        ),
      ],
    );
  }

  Future<void> _showDatePicker() async {
    DateTime now = DateTime.now();
    DateTime initialDate = widget.initialValue ?? now;

    DateTime firstDate =
        widget.firstDate ?? Jiffy(now).subtract(years: widget.yearsRange);
    // Apply a tolerance.
    if (Jiffy(firstDate).add(years: 1).isAfter(initialDate)) {
      firstDate = Jiffy(initialDate).subtract(years: widget.yearsRange);
    }

    DateTime lastDate =
        widget.lastDate ?? Jiffy(now).add(years: widget.yearsRange);
    // Apply a tolerance.
    if (Jiffy(lastDate).subtract(years: 1).isBefore(initialDate)) {
      lastDate = Jiffy(initialDate).add(years: widget.yearsRange);
    }

    DateTime picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      widget.onValueChanged(picked);
    }
  }

  Future<void> _showTimePicker() async {
    TimeOfDay initialTime = widget.initialValue != null
        ? TimeOfDay.fromDateTime(widget.initialValue)
        : TimeOfDay.now();
    TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      var newValue = widget.initialValue ?? DateTime.now();
      newValue = DateTime(
          newValue.year,
          newValue.month,
          newValue.day,
          picked.hour,
          picked.minute,
          newValue.second,
          newValue.millisecond,
          newValue.microsecond);

      widget.onValueChanged(newValue);
    }
  }
}
