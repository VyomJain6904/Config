pragma Singleton
import Quickshell

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    QUICKSHELL GLOBAL DESIGN SYSTEM & THEME
 * ─────────────────────────────────────────────────────────────────────────────
 * Central design token registry for panels, widgets, dialogs, and AI views.
 * All measurements in Qt pixel coordinates; colors in ARGB/RGB hex formatting.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Singleton {

    // =========================================================================
    // 1. COLOR PALETTE (Monochrome Black)
    // =========================================================================

    // Core Backgrounds & Surfaces
    readonly property string transparent: "#00000000"       // Fully transparent UI layer
    readonly property string bg: "#101010"                  // Primary deep charcoal background
    readonly property string barBackground: "#000000"       // System panel black background
    readonly property string surface: "#171717"             // Default card and menu container surface
    readonly property string surfaceHover: "#1e1e1e"        // Interactive hover state surface
    readonly property string surfaceActive: "#3d4468"       // Active workspace and selected item highlight (Tokyo Night Slate)

    // Shared Utility & Menu Button Palette
    // Keeps handcrafted controls and reusable button components unified
    readonly property string buttonBackground: surface
    readonly property string buttonHoverBackground: surfaceHover
    readonly property string buttonFocusBackground: "#242424"       // Keyboard focused and interactive button background
    readonly property string buttonSelectedBackground: accent

    // Borders & Dividers
    readonly property string border: "#242424"              // Subtle separating border line color
    readonly property string borderStrong: "#242424"        // Prominent outline and structural border color

    // Typography & Text Colors
    readonly property string text: "#c0caf5"                // Primary standard body text (Tokyo Night Periwinkle)
    readonly property string textStrong: "#e0e0e0"          // Emphasized headers and high-contrast titles
    readonly property string textMuted: "#555555"           // Inactive workspaces and secondary metadata
    readonly property string placeholder: "#444444"         // Disabled text and form input placeholders

    // Accents & Semantic Status Tints
    readonly property string accent: "#c0caf5"              // Primary theme brand accent color
    readonly property string accentSecondary: "#888888"     // Secondary accent and neutral decorative icons
    readonly property string accentText: "#000000"          // Dark text over vibrant active accent surfaces
    readonly property string danger: "#ff5555"              // Critical alerts, errors, and disconnect status
    readonly property string success: "#50fa7b"             // Online status, active connections, and positive badges
    readonly property string shadow: "#70000000"            // Semi-transparent window drop shadows

    // =========================================================================
    // 2. TYPOGRAPHY & FONT SCALES
    // =========================================================================

    // Font Family Definitions
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string iconFontFamily: fontFamily

    // Font Pixel Dimensions
    readonly property int titleFontSize: 18                 // Window titles, modals, and primary dialog headings
    readonly property int inputFontSize: 16                 // Text input fields, CLI bars, and search boxes
    readonly property int bodyFontSize: 14                  // Standard list items, labels, and descriptions
    readonly property int smallFontSize: 12                 // Sub-labels, captions, metadata, and timestamps
    property int panelFontSize: 12                          // System panel workspace digits and compact status indicators
    readonly property int tinyFontSize: 10                  // Compact badges, footnotes, and fine print

    // =========================================================================
    // 3. PANEL & STATUS BAR GEOMETRY
    // =========================================================================

    readonly property int panelHeight: 24                   // Global bar thickness (synchronized with exclusiveZone)
    readonly property int panelMargin: 0                    // Offset around panel exterior margins
    readonly property int panelEdgeMargin: 0                // Distance from left and right screen boundaries
    readonly property int panelGap: 4                       // Spacing between major panel item groups

    // =========================================================================
    // 4. COMPONENT & WIDGET SIZING (Pills, Workspaces & System Tray)
    // =========================================================================

    // Panel Pills (Network, Audio, Bluetooth indicator capsules)
    readonly property int pillRadius: 0                     // Capsule corner rounding (0 = sharp square geometry)
    readonly property int pillHeight: 20                    // Capsule height inside bar
    readonly property int pillHorizontalPadding: 8          // Left/right padding around pill text and icons
    readonly property int pillBorderWidth: 0                // Border thickness around active status pills

    // Workspace & System Tray Items
    readonly property int workspaceButtonSize: 20           // Workspace switcher button width and height
    readonly property int trayItemSize: 20                  // System tray container box dimensions
    readonly property int trayIconSize: 16                  // Render size for tray icons (leaves clean 2px vertical margins)

    // =========================================================================
    // 5. LAYOUT SPACINGS & CORNER GEOMETRY
    // =========================================================================

    // Popups, Menus, and Lists Spacing
    readonly property int popupMargin: 18                   // Margin between popup windows and panel edges
    readonly property int popupSpacing: 12                  // Spacing between elements within popup cards
    readonly property int rowSpacing: 10                    // Vertical distance between standard UI rows
    readonly property int listSpacing: 4                    // Tight spacing for dropdown and selectable list items
    readonly property int compactSpacing: 2                 // Minimal spacing for closely associated indicators
    readonly property int sectionSpacing: 14                // Large separation between independent content sections

    // Global Corner Radii & Animations
    readonly property int radius: 0                         // Default card and dialog corner rounding
    readonly property int smallRadius: 0                    // Compact badge and small button rounding
    readonly property int barRadius: 0                      // Main top system panel bar rounding
    readonly property int animationNormal: 180              // Default animation transition duration (in milliseconds)

    // =========================================================================
    // 6. STANDARD CONTROL HEIGHTS
    // =========================================================================

    readonly property int buttonHeight: 30                  // Standard action button thickness
    readonly property int chipHeight: 28                    // Interactive filter and selection chips
    readonly property int confirmButtonHeight: 48           // Prominent modal confirmation buttons
}
