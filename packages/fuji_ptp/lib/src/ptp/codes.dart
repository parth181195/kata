// PTP (ISO 15740) and Fujifilm vendor codes.

class ContainerType {
  static const command = 0x0001;
  static const data = 0x0002;
  static const response = 0x0003;
  static const event = 0x0004;
}

class Op {
  static const getDeviceInfo = 0x1001;
  static const openSession = 0x1002;
  static const closeSession = 0x1003;
  static const getStorageIDs = 0x1004;
  static const getObjectHandles = 0x1007;
  static const getObject = 0x1009;
  static const deleteObject = 0x100B;
  static const getDevicePropDesc = 0x1014;
  static const getDevicePropValue = 0x1015;
  static const setDevicePropValue = 0x1016;
  // Fuji vendor (RAW conversion upload)
  static const fujiSendObjectInfo = 0x900C;
  static const fujiSendObject2 = 0x900D;
}

class Resp {
  static const ok = 0x2001;
  static const generalError = 0x2002;
  static const sessionNotOpen = 0x2003;
  static const invalidTransactionId = 0x2004;
  static const operationNotSupported = 0x2005;
  static const parameterNotSupported = 0x2006;
  static const incompleteTransfer = 0x2007;
  static const invalidStorageId = 0x2008;
  static const invalidObjectHandle = 0x2009;
  static const devicePropNotSupported = 0x200A;
  static const invalidDevicePropValue = 0x201C;
  static const invalidParameter = 0x201D;
  static const sessionAlreadyOpen = 0x201E;
  static const deviceBusy = 0x2019;

  static const names = <int, String>{
    ok: 'OK',
    generalError: 'GeneralError',
    sessionNotOpen: 'SessionNotOpen',
    invalidTransactionId: 'InvalidTransactionID',
    operationNotSupported: 'OperationNotSupported',
    parameterNotSupported: 'ParameterNotSupported',
    incompleteTransfer: 'IncompleteTransfer',
    invalidStorageId: 'InvalidStorageID',
    invalidObjectHandle: 'InvalidObjectHandle',
    devicePropNotSupported: 'DevicePropNotSupported',
    invalidDevicePropValue: 'InvalidDevicePropValue',
    invalidParameter: 'InvalidParameter',
    sessionAlreadyOpen: 'SessionAlreadyOpen',
    deviceBusy: 'DeviceBusy',
    0x2020: 'InvalidDevicePropFormat',
    0x2021: 'InvalidDevicePropValue',
    0x201F: 'TransactionCancelled',
    0x2016: 'AccessDenied',
  };

  /// Plain-language names for anything a user might see. Kept beside [names] so the two
  /// can't drift; [name] stays the wire-level label for logs and the probe screen.
  static const friendlyNames = <int, String>{
    0xD18C: 'Slot',
    0xD18D: 'Name',
    0xD18E: 'Image size',
    0xD18F: 'Image quality',
    0xD190: 'Dynamic range',
    0xD191: 'Unknown setting (D191)',
    0xD192: 'Film simulation',
    0xD193: 'Monochromatic colour (warm/cool)',
    0xD194: 'Monochromatic colour (green/magenta)',
    0xD195: 'Grain effect',
    0xD196: 'Colour chrome effect',
    0xD197: 'Colour chrome FX blue',
    0xD198: 'Smooth skin effect',
    0xD199: 'White balance',
    0xD19A: 'WB shift (red)',
    0xD19B: 'WB shift (blue)',
    0xD19C: 'Colour temperature',
    0xD19D: 'Highlight tone',
    0xD19E: 'Shadow tone',
    0xD19F: 'Colour',
    0xD1A0: 'Sharpness',
    0xD1A1: 'High ISO NR',
    0xD1A2: 'Clarity',
    0xD1A3: 'Long exposure NR',
    0xD1A4: 'Colour space',
    0xD1A5: 'Unknown setting (D1A5)',
  };

  static String friendly(int code) => friendlyNames[code] ?? name(code);

  static String name(int code) =>
      names[code] ?? '0x${code.toRadixString(16).toUpperCase().padLeft(4, '0')}';
}

/// Fujifilm device property codes relevant to the probe.
class FujiProp {
  static const currentState = 0xD212;
  static const presetSlot = 0xD18C;
  static const presetName = 0xD18D;
  static const presetFirst = 0xD18E;
  static const presetLast = 0xD1A5;
  static const filmSimulation = 0xD192;

  static const names = <int, String>{
    0xD001: 'FilmSimulation(shoot)',
    0xD183: 'StartRawConversion',
    0xD185: 'RawConvProfile',
    0xD212: 'CurrentState',
    0xD18C: 'PresetSlot',
    0xD18D: 'PresetName',
    0xD18E: 'P:ImageSize',
    0xD18F: 'P:ImageQuality',
    0xD190: 'P:DynamicRange%',
    0xD191: 'P:?D191',
    0xD192: 'P:FilmSimulation',
    0xD193: 'P:MonoWC×10',
    0xD194: 'P:MonoMG×10',
    0xD195: 'P:GrainEffect',
    0xD196: 'P:ColorChrome',
    0xD197: 'P:ColorChromeFxBlue',
    0xD198: 'P:SmoothSkin',
    0xD199: 'P:WhiteBalance',
    0xD19A: 'P:WBShiftR',
    0xD19B: 'P:WBShiftB',
    0xD19C: 'P:ColorTemp(K)',
    0xD19D: 'P:HighlightTone×10',
    0xD19E: 'P:ShadowTone×10',
    0xD19F: 'P:Color×10',
    0xD1A0: 'P:Sharpness×10',
    0xD1A1: 'P:HighIsoNR',
    0xD1A2: 'P:Clarity×10',
    0xD1A3: 'P:LongExpNR',
    0xD1A4: 'P:ColorSpace',
    0xD1A5: 'P:?D1A5',
  };

  /// Plain-language names for anything a user might see. Kept beside [names] so the two
  /// can't drift; [name] stays the wire-level label for logs and the probe screen.
  static const friendlyNames = <int, String>{
    0xD18C: 'Slot',
    0xD18D: 'Name',
    0xD18E: 'Image size',
    0xD18F: 'Image quality',
    0xD190: 'Dynamic range',
    0xD191: 'Unknown setting (D191)',
    0xD192: 'Film simulation',
    0xD193: 'Monochromatic colour (warm/cool)',
    0xD194: 'Monochromatic colour (green/magenta)',
    0xD195: 'Grain effect',
    0xD196: 'Colour chrome effect',
    0xD197: 'Colour chrome FX blue',
    0xD198: 'Smooth skin effect',
    0xD199: 'White balance',
    0xD19A: 'WB shift (red)',
    0xD19B: 'WB shift (blue)',
    0xD19C: 'Colour temperature',
    0xD19D: 'Highlight tone',
    0xD19E: 'Shadow tone',
    0xD19F: 'Colour',
    0xD1A0: 'Sharpness',
    0xD1A1: 'High ISO NR',
    0xD1A2: 'Clarity',
    0xD1A3: 'Long exposure NR',
    0xD1A4: 'Colour space',
    0xD1A5: 'Unknown setting (D1A5)',
  };

  static String friendly(int code) => friendlyNames[code] ?? name(code);

  static String name(int code) =>
      names[code] ?? '0x${code.toRadixString(16).toUpperCase().padLeft(4, '0')}';
}

const fujiVendorId = 0x04CB;
