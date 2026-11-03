import 'package:flutter/foundation.dart';

/// Whether this is the DEV app (`de.gymlog.app.dev`).
///
/// Debug and profile builds are installed as the DEV app (see
/// android/app/build.gradle.kts); only release builds are the real app.
/// Dev-only features (demo data, delete all data) are gated by this.
const bool isDevBuild = !kReleaseMode;
