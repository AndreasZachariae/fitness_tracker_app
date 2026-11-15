# Release builds only (Flutter enables R8 for "release"; the DEV build is not shrunk).
# 1.6.3: the real app did not ask for "Geräte in der Nähe" while the DEV app did. GymLog now asks itself
# (MainActivity); keeping the Bluetooth plugin whole rules out that shrinking breaks the plugin otherwise.
-keep class com.navideck.universal_ble.** { *; }
