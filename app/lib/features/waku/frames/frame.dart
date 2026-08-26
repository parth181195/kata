import 'dart:ui';

import '../../../core/compose/layers.dart';
import '../../../core/compose/roll.dart';
import '../waku_exif.dart';
import '../waku_grain_measure.dart';
import 'stamp.dart';

/// Everything an object needs to build itself for one output.
class ObjectContext {
  const ObjectContext({
    required this.size,
    required this.meta,
    required this.grain,
    required this.palette,
    required this.roll,
    this.kataName,
    this.kataCode,
  });

  final Size size;
  final PhotoMeta meta;
  final PhotoGrain grain;
  final List<Color> palette;
  final Roll roll;

  /// The attached recipe's name, when there is one.
  final String? kataName;

  /// The `kata1:` payload, for the object's code furniture.
  final String? kataCode;
}

/// A printed object. Its identity and its slots are authored here; only
/// [allowances] may be rolled (docs/design/waku-spec.md §3).
abstract class WakuObject {
  const WakuObject();

  /// Stable id, used for pinning and for the object drawer.
  String get id;

  /// What the drawer calls it.
  String get label;

  /// What the roll may touch.
  Allowances get allowances;

  /// The layer stack for one output. Must contain exactly one
  /// [ComposePhotoWindow], and every [ComposeTextSlot] must lie on the sheet at
  /// every ratio — `frames_test.dart` fuzzes both.
  List<ComposeLayer> build(ObjectContext ctx);
}

/// Every object the app can produce.
const List<WakuObject> kObjects = [StampObject()];

WakuObject objectById(String id) => kObjects.firstWhere((o) => o.id == id, orElse: () => kObjects.first);
