import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import "../themes"
import "../windows"
import "../components"

ApplicationWindow {
    id: baseWindow

    property int hwnd: 0
    property bool isRinUIWindow: true
    property bool isTileWindow: true
    property real tileTransparency: 0.86
    property bool backdropEnabled: true
    property bool keepBackdropActive: true
    property bool locked: false
    property bool nativeWindowFrame: true
    property bool isMacOS: Qt.platform.os === "osx" || Qt.platform.os === "macos" || Qt.platform.os === "darwin"
    property bool isWindows: Qt.platform.os === "windows"
    property bool useNativeMacFrame: isMacOS
    property int macNativeContentVerticalOffset: useNativeMacFrame ? -2 : 0
    property int expandedClientAreaHint: typeof Qt.ExpandedClientAreaHint !== "undefined"
        ? Qt.ExpandedClientAreaHint
        : 0
    property int noTitleBarBackgroundHint: typeof Qt.NoTitleBarBackgroundHint !== "undefined"
        ? Qt.NoTitleBarBackgroundHint
        : 0

    flags: useNativeMacFrame
        ? (Qt.Window
            | Qt.CustomizeWindowHint
            | Qt.WindowTitleHint
            | Qt.WindowSystemMenuHint
            | Qt.ExpandedClientAreaHint
            | Qt.NoTitleBarBackgroundHint
            | Qt.WindowMinimizeButtonHint
            | Qt.WindowMaximizeButtonHint
            | Qt.WindowCloseButtonHint)
        : (Qt.Window | Qt.FramelessWindowHint)
    color: "transparent"
    topPadding: 0

    Component.onCompleted: {
        if (baseWindow.isWindows && baseWindow.nativeWindowFrame) {
            baseWindow.flags = baseWindow.flags & ~Qt.FramelessWindowHint
            WinEventManager.syncWindowFrame(baseWindow)
        } else if (baseWindow.isWindows) {
            WinEventManager.syncWindowFrame(baseWindow)
        }
    }

    property var icon: ""
    property alias titleEnabled: titleBar.titleEnabled
    property alias minimizeEnabled: titleBar.minimizeEnabled
    property bool maximizeEnabled: maximumHeight === 16777215 && maximumWidth === 16777215
    property alias closeEnabled: titleBar.closeEnabled
    property alias minimizeVisible: titleBar.minimizeVisible
    property alias maximizeVisible: titleBar.maximizeVisible
    property alias closeVisible: titleBar.closeVisible

    property int titleBarHeight: Theme.currentTheme.appearance.dialogTitleBarHeight
    property alias titleBarArea: titleBar.content
    property alias titleBarHost: titleBar.contentHost
    property alias titleBarLeadingArea: titleBar.leadingContent
    property alias titleBarLeadingHost: titleBar.leadingContentHost
    property alias framelessMenuBar: menuBarArea.children
    default property alias content: contentArea.children
    property alias floatLayer: floatLayer

    onVisibilityChanged: {
        if (baseWindow.useNativeMacFrame) {
            background.radius = 0
            background.border.width = 0
            return
        }
        if (baseWindow.visibility === Window.Maximized) {
            background.radius = 0
            background.border.width = 1
        } else {
            background.radius = Theme.currentTheme.appearance.windowRadius
            background.border.width = 1
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: baseWindow.useNativeMacFrame ? 0 : Utils.windowDragArea
        anchors.leftMargin: baseWindow.useNativeMacFrame ? 0 : Utils.windowDragArea
        anchors.rightMargin: baseWindow.useNativeMacFrame ? 0 : Utils.windowDragArea
        spacing: 0

        Item {
            Layout.preferredHeight: titleBar.height
            Layout.fillWidth: true
        }

        Item {
            id: menuBarArea
            Layout.fillWidth: true
        }

        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    TitleBar {
        id: titleBar
        window: baseWindow
        icon: baseWindow.icon || ""
        title: baseWindow.title || ""
        useNativeMacControls: baseWindow.useNativeMacFrame
        Layout.fillWidth: true
        height: baseWindow.titleBarHeight
        maximizeEnabled: baseWindow.maximizeEnabled
    }

    background: Rectangle {
        id: background
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.currentTheme.colors.windowBorderColor
        border.width: baseWindow.useNativeMacFrame ? 0 : 1
        radius: baseWindow.useNativeMacFrame ? 0 : Theme.currentTheme.appearance.windowRadius
        z: -1
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: !baseWindow.useNativeMacFrame
            color: {
                if (!baseWindow.backdropEnabled)
                    return Theme.currentTheme.colors.backgroundColor
                const t = Math.max(0, Math.min(1, baseWindow.tileTransparency))
                const alpha = 0.08 + (1.0 - t) * 0.40
                if (Theme.currentTheme.isDark)
                    return Qt.rgba(0.07, 0.08, 0.10, alpha)
                return Qt.rgba(0.98, 0.99, 1.0, alpha)
            }
        }

        Image {
            anchors.fill: parent
            source: "../assets/img/noise.png"
            fillMode: Image.Tile
            opacity: baseWindow.backdropEnabled ? 0.04 : 0.025
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: parent.border.width
            border.color: parent.border.color
        }
    }

    FloatLayer {
        id: floatLayer
        anchors.topMargin: titleBarHeight
        z: 998
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: !baseWindow.useNativeMacFrame && baseWindow.visibility !== Window.Maximized
        z: -1
        cursorShape: {
            if (baseWindow.useNativeMacFrame || baseWindow.visibility === Window.Maximized) {
                return Qt.ArrowCursor
            }
            const p = Qt.point(mouseX, mouseY)
            const b = Utils.windowDragArea
            if (p.x < b && p.y < b) return Qt.SizeFDiagCursor
            if (p.x >= width - b && p.y >= height - b) return Qt.SizeFDiagCursor
            if (p.x >= width - b && p.y < b) return Qt.SizeBDiagCursor
            if (p.x < b && p.y >= height - b) return Qt.SizeBDiagCursor
            if (p.x < b || p.x >= width - b) return Qt.SizeHorCursor
            if (p.y < b || p.y >= height - b) return Qt.SizeVerCursor
            return Qt.ArrowCursor
        }
        acceptedButtons: Qt.NoButton
    }

    DragHandler {
        id: resizeHandler
        grabPermissions: TapHandler.TakeOverForbidden
        target: null
        enabled: !baseWindow.locked && !baseWindow.useNativeMacFrame && baseWindow.visibility !== Window.Maximized
        onActiveChanged: if (active && baseWindow.visibility !== Window.Maximized) {
            const p = resizeHandler.centroid.position
            const b = Utils.windowDragArea
            let e = 0
            if (p.x < b) e |= Qt.LeftEdge
            if (p.x >= width - b) e |= Qt.RightEdge
            if (p.y < b) e |= Qt.TopEdge
            if (p.y >= height - b) e |= Qt.BottomEdge
            if (e !== 0) baseWindow.startSystemResize(e)
        }
    }
}
