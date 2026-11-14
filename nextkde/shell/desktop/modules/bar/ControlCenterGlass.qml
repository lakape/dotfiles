import QtQuick
import qs.desktop.modules.common
import qs.desktop.modules.dock
import "../../../Kos/Ui"

// One material recipe for controls, notifications and their glass buttons.
// Adaptive Apple liquid glass: dark smoked glass on light/white backdrops,
// clear liquid glass on dark backdrops.
LiquidGlassPanel {
    cornerExponent: 2.35
    baseColor: ThemeService.barGlassBg
    material: "regular"
    materialDepth: 0
    scrimEnabled: true
    scrimLevel: ThemeService.isLightBackdrop ? "strong" : "subtle"
    tintColor: ThemeService.isLightBackdrop ? "black" : "white"
    tintOpacity: ThemeService.isLightBackdrop ? 0.38 : 0
    scrimTintOverride: ThemeService.isLightBackdrop ? 0 : -1
}
