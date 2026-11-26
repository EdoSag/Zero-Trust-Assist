import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Assist's accent in the suite (fuchsia). The brand seed (indigo) is shared
/// by every app.
const Color assistAccent = Color(0xFFD946EF);

/// Assist in the suite. Not in the core's `ZtSuite` list yet, so the other
/// apps don't link to it before it is released.
const ZtSuiteApp assistSuiteApp = ZtSuiteApp(
  appId: 'assist',
  name: 'Assist',
  tagline: 'A private assistant that runs on your phone',
  icon: Icons.auto_awesome_outlined,
  accent: assistAccent,
  androidPackage: 'dev.sagron.zerotrustassist',
);

const ZtAppConfig assistAppConfig = ZtAppConfig(
  appId: 'assist',
  displayName: 'Zero-Trust Assist',
  accent: assistAccent,
);
