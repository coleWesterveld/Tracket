import 'package:flutter/material.dart';

// Utility to grow/shrink a List<T>, disposing controllers if needed
void ensureLength<T>(List<T> list, int targetLen, T Function() make) {
  // grow
  while (list.length < targetLen) {
    list.add(make());
  }
  // shrink
  while (list.length > targetLen) {
    final removed = list.removeLast();
    if (removed is TextEditingController)    removed.dispose();
    if (removed is FocusNode)                removed.dispose();
    //if (removed is ExpansionTileController)  removed.dispose();
    // if it’s a List<…> you’ll eventually hit inner controllers which
    // will be disposed by their own ensureLength calls
  }
}