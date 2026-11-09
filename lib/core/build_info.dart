import 'package:flutter/foundation.dart';

/// Whether this is the DEV app (`de.gymlog.app.dev`).
///
/// Debug and profile builds are installed as the DEV app (see
/// android/app/build.gradle.kts); so is the release-mode "beta" build that
/// is distributed over GitHub (1.2.2, `--dart-define=GYMLOG_DEV=true`).
/// Only release builds are the real app. Dev-only features (demo data,
/// delete all data, the DEV update channel) are gated by this.
const bool isDevBuild = !kReleaseMode || bool.fromEnvironment('GYMLOG_DEV');
