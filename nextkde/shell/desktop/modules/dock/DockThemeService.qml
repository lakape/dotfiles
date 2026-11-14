pragma Singleton
import QtQuick
import qs.desktop.modules.common

// ────────────────────────────────────────────────────────────────
// DockThemeService — Dark / light colour palette.
// Switches reactively with the shell-wide appearance mode.
// Every visual component binds to these colours; no hardcoded values.
// ────────────────────────────────────────────────────────────────

QtObject {
    id: svc

    // AppearanceTokens owns the global system/light/dark resolution so Dock
    // and every Material surface always select the same palette branch.
    readonly property bool isDark: AppearanceTokens.isDarkTheme || isLightBackdrop

    // ═══════════════════════════════════════════════════
    // Dark palette
    // ═══════════════════════════════════════════════════
    // Liquid Glass keeps a neutral, theme-stable body behind its adaptive
    // reflections.  The material may borrow colour from the wallpaper, but
    // it must not borrow so much luminance that label contrast collapses.
    readonly property color darkBg: Qt.rgba(0, 0, 0, 0.10)
    readonly property color darkFg: Qt.rgba(0.985, 0.990, 1.000, 1.0)
    readonly property color darkSecondaryFg: Qt.rgba(0.985, 0.990, 1.000, 0.82)
    readonly property color darkTertiaryFg: Qt.rgba(0.985, 0.990, 1.000, 0.62)
    readonly property color darkAccent: Qt.rgba(0.20, 0.60, 1.0, 1.0)
    readonly property color darkDivider: Qt.rgba(1.0, 1.0, 1.0, 0.18)
    readonly property color darkTooltipBg: Qt.rgba(0.18, 0.18, 0.20, 0.95)
    readonly property color darkIndicator: Qt.rgba(0.985, 0.990, 1.000, 0.90)
    readonly property color darkBorder: Qt.rgba(1.0, 1.0, 1.0, 0.16)
    readonly property color darkHighlight: Qt.rgba(1.0, 1.0, 1.0, 0.28)

    // ═══════════════════════════════════════════════════
    // Light palette
    // ═══════════════════════════════════════════════════
    readonly property color lightBg: Qt.rgba(0.95, 0.95, 0.97, 0.35)
    readonly property color lightFg: Qt.rgba(0.055, 0.065, 0.085, 1.0)
    readonly property color lightSecondaryFg: Qt.rgba(0.055, 0.065, 0.085, 0.72)
    readonly property color lightTertiaryFg: Qt.rgba(0.055, 0.065, 0.085, 0.62)
    readonly property color lightAccent: Qt.rgba(0.0, 0.50, 0.90, 1.0)
    readonly property color lightDivider: Qt.rgba(0.055, 0.065, 0.085, 0.16)
    readonly property color lightTooltipBg: Qt.rgba(0.92, 0.92, 0.94, 0.95)
    readonly property color lightIndicator: Qt.rgba(0.055, 0.065, 0.085, 0.85)
    readonly property color lightBorder: Qt.rgba(0.055, 0.065, 0.085, 0.14)
    readonly property color lightHighlight: Qt.rgba(1.0, 1.0, 1.0, 0.55)

    // ═══════════════════════════════════════════════════
    // Exposed (reactively toggled)
    // ═══════════════════════════════════════════════════
    // ═══════════════════════════════════════════════════
    // Top Bar & Bar Functions Palette (Adaptive Apple Liquid Glass)
    // ═══════════════════════════════════════════════════
    readonly property color barGlassBg: isLightBackdrop
        ? Qt.rgba(0.12, 0.12, 0.16, 0.76)
        : backgroundColor
    readonly property color barGlassFg: isLightBackdrop
        ? Qt.rgba(0.985, 0.990, 1.000, 1.0)
        : foregroundColor
    readonly property color barGlassSecondaryFg: isLightBackdrop
        ? Qt.rgba(0.985, 0.990, 1.000, 0.78)
        : secondaryForegroundColor
    readonly property color barGlassTertiaryFg: isLightBackdrop
        ? Qt.rgba(0.985, 0.990, 1.000, 0.58)
        : tertiaryForegroundColor
    readonly property color barGlassCardBg: isLightBackdrop
        ? Qt.rgba(1.0, 1.0, 1.0, 0.12)
        : AppearanceTokens.surface.pick(AppearanceTokens.colors.surfaceContainerHigh, (isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.05)))
    readonly property color barGlassCardHover: isLightBackdrop
        ? Qt.rgba(1.0, 1.0, 1.0, 0.18)
        : AppearanceTokens.surface.pick(AppearanceTokens.colors.surfaceContainerHigh, (isDark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.08)))
    readonly property color barGlassCardBorder: isLightBackdrop
        ? Qt.rgba(1.0, 1.0, 1.0, 0.16)
        : AppearanceTokens.surface.pick(AppearanceTokens.colors.surfaceContainerHigh, (isDark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.08)))
    readonly property color barGlassDivider: isLightBackdrop
        ? Qt.rgba(1.0, 1.0, 1.0, 0.14)
        : dividerColor

    // Dynamic detection of bright backdrop:
    // 1. Desktop wallpaper is bright/white
    // 2. An active or visible window at the top of the screen (e.g. maximized Chromium) is light
    readonly property bool hasLightTopWindow: {
        const _rev = WindowService.placementRevision;
        const _wrev = WindowService.revision;
        const activeId = WindowService.activeWindowId;
        const win = activeId ? WindowService.windowById(activeId) : null;
        
        const isMin = function(c) {
            return !c || (c.toplevel && c.toplevel.minimized) || Boolean(c.minimized);
        };
        const coversTop = function(c) {
            if (!c || isMin(c)) return false;
            const top = c.toplevel;
            const geom = c.geometry || (top ? top.geometry : null);
            const isMax = Boolean(c.maximized || c.isMaximized || (top && (top.maximized || top.fullscreen)) || c.fullscreen);
            if (isMax) return true;
            if (geom && geom.y <= 50 && geom.height > 150) return true;
            if (c.activated || (top && top.activated)) {
                return !geom || (geom.y <= 100 && geom.height > 200);
            }
            return false;
        };
        const isDarkApp = function(c) {
            if (!c) return false;
            const top = c.toplevel;
            const appId = String(c.identity?.rawAppId || c.identity?.desktopId || top?.appId || c.appId || "").toLowerCase();
            const title = String(c.title || top?.title || "").toLowerCase();
            return appId.includes("terminal") || appId.includes("konsole")
                || appId.includes("kitty") || appId.includes("alacritty")
                || appId.includes("wezterm") || appId.includes("foot")
                || title.endsWith("— alacritty") || title.endsWith("— konsole");
        };

        if (coversTop(win)) {
            return !isDarkApp(win);
        }

        const kwinList = WindowService._kwinWindows || [];
        for (let i = 0; i < kwinList.length; ++i) {
            const kw = kwinList[i];
            if (coversTop(kw)) {
                return !isDarkApp(kw);
            }
        }

        const list = WindowService.records || [];
        for (let i = 0; i < list.length; ++i) {
            const r = list[i];
            if (coversTop(r)) {
                return !isDarkApp(r);
            }
        }

        return false;
    }

    readonly property bool isLightBackdrop: ((AppearanceTokens.bar?.macBackdropLuminance ?? 0) > 0.5) || hasLightTopWindow
    // Darker Apple-like liquid glass plate when background is white/light
    readonly property color darkAppleGlassBg: Qt.rgba(0.12, 0.12, 0.16, 0.68)
    readonly property color effectiveGlassBg: isLightBackdrop ? darkAppleGlassBg : (isDark ? darkBg : lightBg)

    readonly property color backgroundColor: AppearanceTokens.surface.pick(AppearanceTokens.colors.layer0, effectiveGlassBg)
    // Glass foreground follows the resolved appearance: clean dark ink on a
    // light surface, and light ink on a dark surface. This role is shared by
    // launcher labels, symbolic tray icons, Dock glyphs and status content.
    readonly property color foregroundColor: isLightBackdrop ? darkFg : AppearanceTokens.surface.pick(AppearanceTokens.colors.surfaceForeground, (isDark ? darkFg : lightFg))
    // The Bar's ink while the mac style owns the ground. Normally the Bar
    // borrows the glass foreground -- white on the dark glass, which is
    // exactly why its labels and glyphs carry a readability outline. With the
    // strip on there is a tinted plate behind them, and the ink flips against
    // what the strip actually looks like -- the wallpaper blended with the
    // plate at the chosen tint (AppearanceTokens.bar.macStripIsLight) -- so
    // black type lands on the light end of the strip and white on the dark
    // end at every slider position, not just at full tint.
    readonly property color barInk: isLightBackdrop
        ? "#ffffff"
        : (AppearanceTokens.bar.macStyle
            ? (AppearanceTokens.bar.macStripIsLight ? "#000000" : "#ffffff")
            : foregroundColor)
    readonly property color secondaryForegroundColor: AppearanceTokens.surface.pick(AppearanceTokens.colors.surfaceVariantForeground, (isDark ? darkSecondaryFg : lightSecondaryFg))
    readonly property color tertiaryForegroundColor: AppearanceTokens.surface.pick(Qt.rgba(AppearanceTokens.colors.surfaceVariantForeground.r,
            AppearanceTokens.colors.surfaceVariantForeground.g,
            AppearanceTokens.colors.surfaceVariantForeground.b, 0.70), (isDark ? darkTertiaryFg : lightTertiaryFg))
    readonly property color accentColor: AppearanceTokens.surface.pick(AppearanceTokens.colors.primary, (isDark ? darkAccent : lightAccent))
    readonly property color dividerColor: AppearanceTokens.surface.pick(AppearanceTokens.colors.outline, (isDark ? darkDivider : lightDivider))
    readonly property color tooltipBackground: AppearanceTokens.surface.pick(AppearanceTokens.colors.layer3, (isDark ? darkTooltipBg : lightTooltipBg))
    // Material keeps the running dot on the high-contrast on-surface ink so it
    // never falls back to a seed-driven primary that may not reach AA contrast
    // against the tonal dock layer. Glass branches use the indicator inks above.
    readonly property color indicatorColor: AppearanceTokens.surface.pick(AppearanceTokens.colors.surfaceForeground, (isDark ? darkIndicator : lightIndicator))
    readonly property color borderColor: AppearanceTokens.surface.pick(AppearanceTokens.colors.outline, (isDark ? darkBorder : lightBorder))
    // ── Control-centre tiles ─────────────────────────────────────────────
    // A tile is a container, not a glass card: in the tonal form it takes the
    // scheme's container fills and the ink that reads on them. Each role keeps
    // exactly the literal the tiles were drawn with as its glass value while
    // the tile is dark, so the default glass form stays byte-identical and only
    // the tonal form (or a light glass) changes.
    readonly property color tileGlyph: isLightBackdrop ? "white" : AppearanceTokens.surface.pick(
        AppearanceTokens.colors.surfaceVariantForeground,
        (isDark ? "white" : lightFg))
    readonly property color tileActiveGlyph: AppearanceTokens.surface.pick(
        AppearanceTokens.colors.primaryContainerForeground, "white")
    // The fill `tileActiveGlyph` is cut for: an enabled toggle reads as a
    // primaryContainer tile carrying its own on-container ink, not as the
    // accent with a borrowed foreground.
    readonly property color tileActiveFill: AppearanceTokens.surface.pick(
        AppearanceTokens.colors.primaryContainer, "#0a84ff")
    readonly property color tileAccent: AppearanceTokens.surface.pick(
        AppearanceTokens.colors.primary, "#0a84ff")
    readonly property color tileDanger: AppearanceTokens.surface.pick(
        AppearanceTokens.colors.error, "#ff453a")
    readonly property color highlightColor: AppearanceTokens.surface.pick(Qt.rgba(AppearanceTokens.colors.primary.r,
            AppearanceTokens.colors.primary.g,
            AppearanceTokens.colors.primary.b, 0.22), (isDark ? darkHighlight : lightHighlight))
}
