// Why the camera refused a setting — in words a photographer can act on.

import '../ptp/codes.dart';
import 'camera_preset.dart';
import 'fuji_props.dart';

/// One reason, covering the fields it explains. [headline] is hedged where it has to be:
/// nothing in the preset protocol reports HDR or D-Range Priority state, so the rules below
/// infer it from *which* fields came back rejected and *how*.
class SkipCause {
  const SkipCause({required this.headline, required this.detail, required this.codes, required this.fix});

  /// Short, e.g. "HDR or D-Range Priority is on".
  final String headline;

  /// A sentence explaining what the camera did.
  final String detail;

  /// What to do about it, or '' when there's nothing to do.
  final String fix;

  /// Property codes this covers, in write order.
  final List<int> codes;

  List<String> get fields => [for (final c in codes) FujiProp.friendly(c)];
}

/// Fields the camera stops accepting while HDR is on: dynamic range, the tone curve and
/// clarity. D-Range Priority locks the same group minus clarity.
const _toneLockGroup = {0xD190, 0xD191, 0xD19D, 0xD19E, 0xD1A2};

/// Every skipped code comes back inside exactly one cause — a bare list of rejected
/// property names is what this replaces.
List<SkipCause> explainSkips(List<int> skipped, {required CameraPreset preset, Map<int, int> reasons = const {}}) {
  if (skipped.isEmpty) return const [];
  final left = [...skipped];
  final out = <SkipCause>[];

  List<int> take(bool Function(int code) match) {
    final hit = left.where(match).toList();
    left.removeWhere(match);
    return hit;
  }

  // 1. The tone/DR group. D191 is passthrough — its bytes came off this very slot seconds
  // earlier — so a rejection there can't be a value Kata invented: the body is refusing the
  // group right now. Two or more of the group is the same story.
  // ...unless the body simply hasn't got the property: "turn HDR off" is nonsense then.
  bool locked(int code) => reasons[code] != Resp.devicePropNotSupported && reasons[code] != Resp.operationNotSupported;
  final toneHit = skipped.where((c) => _toneLockGroup.contains(c) && locked(c)).toList();
  if (toneHit.contains(0xD191) || toneHit.length >= 2) {
    final clarity = toneHit.contains(0xD1A2);
    final resp = reasons[toneHit.first];
    take(toneHit.contains);
    out.add(SkipCause(
      headline: clarity ? 'HDR is on (or D-Range Priority)' : 'D-Range Priority is on (or HDR)',
      detail: clarity
          ? 'HDR takes over dynamic range, the tone curve and clarity, so the camera refuses them over USB — '
              'it turned down settings it had just handed us. Everything else was written.'
          : 'D-Range Priority drives dynamic range and the highlight/shadow curve itself, so the camera '
              'keeps those fields for its own use. Everything else was written.'
          '${resp == null ? '' : ' (camera said ${Resp.name(resp)})'}',
      fix: 'Set HDR and D-Range Priority to OFF on the camera, then write again.',
      codes: toneHit,
    ));
  }

  // 2. Fields that only exist for some film simulations.
  final mono = take((c) => (c == 0xD193 || c == 0xD194) && !preset.isMono);
  if (mono.isNotEmpty) {
    out.add(SkipCause(
      headline: 'Not a monochrome film simulation',
      detail: 'Warm/cool and green/magenta only exist on Monochrome, Acros and Sepia. '
          '${FilmSim.labels[preset.filmSim] ?? 'This simulation'} has no such setting.',
      fix: '',
      codes: mono,
    ));
  }
  final colour = take((c) => c == 0xD19F && preset.isMono);
  if (colour.isNotEmpty) {
    out.add(SkipCause(
      headline: 'Monochrome has no colour setting',
      detail: '${FilmSim.labels[preset.filmSim] ?? 'This simulation'} is black and white, so the camera has '
          'nowhere to put a colour value.',
      fix: '',
      codes: colour,
    ));
  }
  final kelvin = take((c) => c == 0xD19C && preset.wbMode != WbMode.colorTemp);
  if (kelvin.isNotEmpty) {
    out.add(SkipCause(
      headline: 'White balance is not set to K',
      detail: 'Colour temperature only applies when white balance is Color Temp. '
          'This kata uses ${WbMode.labels[preset.wbMode] ?? 'another mode'}.',
      fix: '',
      codes: kelvin,
    ));
  }

  // 3. Whatever is left, grouped by what the camera answered.
  final byBucket = <String, List<int>>{};
  for (final c in left) {
    byBucket.putIfAbsent(_bucket(reasons[c]), () => []).add(c);
  }
  for (final e in byBucket.entries) {
    final resp = reasons[e.value.first];
    out.add(SkipCause(
      headline: _headline(e.key),
      detail: '${_detail(e.key)}${resp == null ? '' : ' (camera said ${Resp.name(resp)})'}',
      fix: _fix(e.key),
      codes: e.value,
    ));
  }
  return out;
}

String _bucket(int? resp) => switch (resp) {
      Resp.devicePropNotSupported || Resp.operationNotSupported || Resp.parameterNotSupported => 'unsupported',
      Resp.deviceBusy => 'busy',
      Resp.accessDenied || Resp.storeReadOnly => 'locked',
      Resp.invalidDevicePropValue || Resp.invalidDevicePropFormat || Resp.invalidParameter => 'value',
      _ => 'refused',
    };

String _headline(String bucket) => switch (bucket) {
      'unsupported' => "This body doesn't store it in a slot",
      'busy' => 'The camera was busy',
      'locked' => 'Locked by the camera right now',
      'value' => 'The camera turned the value down',
      _ => 'The camera refused it',
    };

String _detail(String bucket) => switch (bucket) {
      'unsupported' => 'The setting exists in the menus but not in the Custom Settings protocol on this model, '
          'so it can only be set on the camera.',
      'busy' => 'It was mid-something — a buffer flush or a menu open — when the write reached it.',
      'locked' => 'Another mode has taken the setting over. HDR, D-Range Priority, a drive mode like pixel-shift '
          'or bracketing, and some film simulations all do this.',
      'value' => 'It accepted the field but not the number. That usually means another setting is capping the '
          'range — D-Range Priority forcing DR400, for example.',
      _ => 'No reason given.',
    };

String _fix(String bucket) => switch (bucket) {
      'unsupported' => 'Set it on the camera after loading the slot.',
      'busy' => 'Write again — it usually lands the second time.',
      'locked' => 'Check HDR, D-Range Priority and the drive mode, then write again.',
      'value' => 'Check HDR and D-Range Priority, then write again.',
      _ => 'Write again; if it keeps happening, check HDR and D-Range Priority.',
    };
