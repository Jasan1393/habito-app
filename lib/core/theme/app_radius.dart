import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const double none = 0;
  static const double sm = 8;
  static const double compactValue = 12;
  static const double md = 14;
  static const double softValue = 15;
  static const double tileValue = 16;
  static const double lg = 18;
  static const double cardValue = 20;
  static const double panelValue = 22;
  static const double xl = 24;
  static const double heroValue = 26;
  static const double bottomSheetValue = 28;
  static const double bottomSheetCompactValue = 26;
  static const double displayValue = 28;
  static const double authPanelValue = 30;
  static const double xxl = 32;
  static const double pill = 999;

  static const BorderRadius small = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius compact = BorderRadius.all(
    Radius.circular(compactValue),
  );
  static const BorderRadius medium = BorderRadius.all(Radius.circular(md));
  static const BorderRadius soft = BorderRadius.all(
    Radius.circular(softValue),
  );
  static const BorderRadius tile = BorderRadius.all(Radius.circular(tileValue));
  static const BorderRadius large = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius card = BorderRadius.all(Radius.circular(cardValue));
  static const BorderRadius panel = BorderRadius.all(
    Radius.circular(panelValue),
  );
  static const BorderRadius extraLarge = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius hero = BorderRadius.all(Radius.circular(heroValue));
  static const BorderRadius display = BorderRadius.all(
    Radius.circular(displayValue),
  );
  static const BorderRadius authPanel = BorderRadius.all(
    Radius.circular(authPanelValue),
  );
  static const BorderRadius bottomSheet = BorderRadius.vertical(
    top: Radius.circular(bottomSheetValue),
  );
  static const BorderRadius bottomSheetCompact = BorderRadius.vertical(
    top: Radius.circular(bottomSheetCompactValue),
  );
  static const BorderRadius extraExtraLarge = BorderRadius.all(
    Radius.circular(xxl),
  );
  static const BorderRadius full = BorderRadius.all(Radius.circular(pill));
}
