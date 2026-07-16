pragma Singleton
import Quickshell

Singleton {
    readonly property bool dark: true

    // Colors - Monochrome Black
    readonly property string transparent: "#00000000"
    readonly property string bg: "#000000"
    readonly property string barBackground: "#000000"
    readonly property string surface: "#111111"
    readonly property string surfaceHover: "#1a1a1a"
    readonly property string surfaceActive: "#222222"
    readonly property string border: "#2a2a2a"
    readonly property string borderStrong: "#333333"
    readonly property string text: "#c0caf5"
    readonly property string textStrong: "#e0e0e0"
    readonly property string textMuted: "#555555"
    readonly property string placeholder: "#444444"
    readonly property string accent: "#c0caf5"
    readonly property string accentSecondary: "#888888"
    readonly property string accentText: "#000000"
    readonly property string success: "#888888"
    readonly property string warning: "#888888"
    readonly property string danger: "#f7768e"
    readonly property string dangerSurface: "#2a1115"
    readonly property string shadow: "#70000000"

    // Font
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string iconFontFamily: fontFamily

    // Panel sizing (match your polybar)
    readonly property int panelHeight: 20
    readonly property int panelMargin: 0
    readonly property int panelEdgeMargin: 0
    readonly property int panelGap: 4
    readonly property int popupMargin: 18
    readonly property int popupSpacing: 12
    readonly property int rowSpacing: 10
    readonly property int listSpacing: 4
    readonly property int compactSpacing: 2
    readonly property int tightSpacing: 3
    readonly property int sectionSpacing: 14
    readonly property int radius: 0
    readonly property int smallRadius: 0
    readonly property int barRadius: 0
    readonly property int pillRadius: 0
    readonly property int pillHeight: 22
    readonly property int pillHorizontalPadding: 8
    readonly property int pillBorderWidth: 0
    readonly property int animationFast: 120
    readonly property int animationNormal: 180
    readonly property int buttonHeight: 30
    readonly property int chipHeight: 28
    readonly property int workspaceButtonSize: 22
    readonly property int compactButtonHeight: 40
    readonly property int confirmButtonHeight: 48
    readonly property int notificationAccentWidth: 4
    readonly property int notificationAccentRadius: 2
    readonly property int titleFontSize: 18
    readonly property int bodyFontSize: 14
    readonly property int panelFontSize: 13
    readonly property int smallFontSize: 12
    readonly property int tinyFontSize: 10
    readonly property int inputFontSize: 16
    readonly property int iconSize: 28
    readonly property int trayItemSize: 24
    readonly property int trayIconSize: 18
    readonly property int closeButtonSize: 30
}
