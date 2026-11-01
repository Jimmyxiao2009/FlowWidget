from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import ctypes

from PySide6.QtCore import QDate, QObject, Property, QSettings, Qt, QTimer, Signal, Slot
from PySide6.QtGui import QGuiApplication, QSurfaceFormat
from PySide6.QtQuick import QQuickWindow, QSGRendererInterface
from PySide6.QtWidgets import QApplication

from .shortcut_model import ShortcutModel
from .shelf_collection import ShelfCollectionModel
from .weather_service import WeatherService


class ShelfSettings(QObject):
    windowTitleChanged = Signal()
    columnsChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._settings = QSettings("FlowWidget", "FlowWidget")
        self._window_title = str(self._settings.value("window/title", "FlowWidget"))
        try:
            columns = int(self._settings.value("layout/columns", 4))
        except (TypeError, ValueError):
            columns = 4
        self._columns = columns if columns in (4, 8) else 4

    @Property(str, notify=windowTitleChanged)
    def windowTitle(self) -> str:
        return self._window_title

    @Property(int, notify=columnsChanged)
    def columns(self) -> int:
        return self._columns

    @Slot(str)
    def setWindowTitle(self, title: str) -> None:
        title = title.strip()
        if not title or title == self._window_title:
            return
        self._window_title = title
        self._settings.setValue("window/title", title)
        self.windowTitleChanged.emit()

    @Slot(int)
    def setColumns(self, columns: int) -> None:
        if columns not in (4, 8) or columns == self._columns:
            return
        self._columns = columns
        self._settings.setValue("layout/columns", columns)
        self.columnsChanged.emit()


class ShelfWindowSettings(QObject):
    """Per-box title plus shared icon layout settings for a floating shelf."""

    windowTitleChanged = Signal()
    columnsChanged = Signal()

    def __init__(
        self,
        collection: ShelfCollectionModel,
        box_id: str,
        layout_settings: ShelfSettings,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._collection = collection
        self._box_id = box_id
        self._layout_settings = layout_settings
        collection.boxesChanged.connect(self.windowTitleChanged.emit)
        layout_settings.columnsChanged.connect(self.columnsChanged.emit)

    @Property(str, notify=windowTitleChanged)
    def windowTitle(self) -> str:
        return self._collection.name_for_box(self._box_id)

    @Property(int, notify=columnsChanged)
    def columns(self) -> int:
        return self._layout_settings.columns

    @Slot(str)
    def setWindowTitle(self, title: str) -> None:
        self._collection.rename_box(self._box_id, title)

    @Slot(int)
    def setColumns(self, columns: int) -> None:
        self._layout_settings.setColumns(columns)


class AppSettings(QObject):
    """Shared, persistent settings used by every FlowWidget window."""

    weatherEnabledChanged = Signal()
    calendarEnabledChanged = Signal()
    countdownEnabledChanged = Signal()
    clockEnabledChanged = Signal()
    focusEnabledChanged = Signal()
    notesEnabledChanged = Signal()
    showGreetingChanged = Signal()
    compactLayoutChanged = Signal()
    showWeekdayChanged = Signal()
    layoutModeChanged = Signal()
    cardOpacityChanged = Signal()
    tileTransparencyChanged = Signal()
    weatherCityChanged = Signal()
    temperatureUnitChanged = Signal()
    countdownTitleChanged = Signal()
    countdownDaysChanged = Signal()
    countdownTargetDateChanged = Signal()
    countdownTargetHourChanged = Signal()
    themeModeChanged = Signal()
    accentColorChanged = Signal()
    backdropEffectChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._settings = QSettings("FlowWidget", "FlowWidget")
        self._weather_enabled = self._bool_value("widgetBoard/weather/visible", True)
        self._calendar_enabled = self._bool_value("widgetBoard/calendar/visible", True)
        self._countdown_enabled = self._bool_value("widgetBoard/countdown/visible", False)
        self._clock_enabled = self._bool_value("widgetBoard/clock/visible", True)
        self._focus_enabled = self._bool_value("widgetBoard/focus/visible", False)
        self._notes_enabled = self._bool_value("widgetBoard/notes/visible", False)
        self._show_greeting = self._bool_value("appearance/showGreeting", True)
        self._compact_layout = self._bool_value("appearance/compactLayout", False)
        self._show_weekday = self._bool_value("calendar/showWeekday", True)
        self._layout_mode = str(self._settings.value("appearance/layoutMode", "auto"))
        if self._layout_mode not in {"auto", "single", "double"}:
            self._layout_mode = "auto"
        try:
            self._card_opacity = float(self._settings.value("appearance/cardOpacity", 0.88))
        except (TypeError, ValueError):
            self._card_opacity = 0.88
        self._card_opacity = min(1.0, max(0.55, self._card_opacity))
        try:
            self._tile_transparency = float(
                self._settings.value("appearance/tileTransparency", 0.86)
            )
        except (TypeError, ValueError):
            self._tile_transparency = 0.86
        self._tile_transparency = min(1.0, max(0.0, self._tile_transparency))
        self._weather_city = str(self._settings.value("weather/city", "武汉市"))
        self._temperature_unit = str(self._settings.value("weather/unit", "C"))
        if self._temperature_unit not in {"C", "F"}:
            self._temperature_unit = "C"
        self._countdown_title = str(
            self._settings.value("countdown/title", "距离下一个目标")
        )
        try:
            self._countdown_days = int(self._settings.value("countdown/days", 12))
        except (TypeError, ValueError):
            self._countdown_days = 12
        self._countdown_days = min(9999, max(0, self._countdown_days))
        default_target = QDate.currentDate().addDays(self._countdown_days).toString(
            "yyyy-MM-dd"
        )
        self._countdown_target_date = str(
            self._settings.value("countdown/targetDate", default_target)
        )
        if not QDate.fromString(self._countdown_target_date, "yyyy-MM-dd").isValid():
            self._countdown_target_date = default_target
        try:
            self._countdown_target_hour = int(
                self._settings.value("countdown/targetHour", 18)
            )
        except (TypeError, ValueError):
            self._countdown_target_hour = 18
        self._countdown_target_hour = min(23, max(0, self._countdown_target_hour))
        self._theme_mode = str(self._settings.value("appearance/themeMode", "Auto"))
        if self._theme_mode not in {"Auto", "Light", "Dark"}:
            self._theme_mode = "Auto"
        self._accent_color = str(
            self._settings.value("appearance/accentColor", "#605ed2")
        )
        default_backdrop = self._default_backdrop_effect()
        self._backdrop_effect = str(
            self._settings.value("appearance/backdropEffect", default_backdrop)
        )
        if self._backdrop_effect not in {"mica", "acrylic", "tabbed", "none"}:
            self._backdrop_effect = default_backdrop
        self._backdrop_effect = self._resolve_backdrop_effect(self._backdrop_effect)
        self._settings.setValue("appearance/backdropEffect", self._backdrop_effect)

    @staticmethod
    def _supports_mica() -> bool:
        if sys.platform != "win32":
            return False
        try:
            return sys.getwindowsversion().build >= 22000
        except (AttributeError, OSError):
            return False

    @classmethod
    def _default_backdrop_effect(cls) -> str:
        if sys.platform != "win32":
            return "none"
        # Acrylic keeps the same translucent appearance when the window loses focus.
        return "acrylic"

    @classmethod
    def _resolve_backdrop_effect(cls, value: str) -> str:
        return value

    def _bool_value(self, key: str, default: bool) -> bool:
        value = self._settings.value(key, default)
        if isinstance(value, str):
            return value.lower() in {"1", "true", "yes"}
        return bool(value)

    def _update(self, attribute: str, value, key: str, signal: Signal) -> None:
        if getattr(self, attribute) == value:
            return
        setattr(self, attribute, value)
        self._settings.setValue(key, value)
        signal.emit()

    @Property(bool, notify=weatherEnabledChanged)
    def weatherEnabled(self) -> bool:
        return self._weather_enabled

    @weatherEnabled.setter
    def weatherEnabled(self, value: bool) -> None:
        self._update("_weather_enabled", bool(value), "widgetBoard/weather/visible", self.weatherEnabledChanged)

    @Property(bool, notify=calendarEnabledChanged)
    def calendarEnabled(self) -> bool:
        return self._calendar_enabled

    @calendarEnabled.setter
    def calendarEnabled(self, value: bool) -> None:
        self._update("_calendar_enabled", bool(value), "widgetBoard/calendar/visible", self.calendarEnabledChanged)

    @Property(bool, notify=countdownEnabledChanged)
    def countdownEnabled(self) -> bool:
        return self._countdown_enabled

    @countdownEnabled.setter
    def countdownEnabled(self, value: bool) -> None:
        self._update("_countdown_enabled", bool(value), "widgetBoard/countdown/visible", self.countdownEnabledChanged)

    @Property(bool, notify=clockEnabledChanged)
    def clockEnabled(self) -> bool:
        return self._clock_enabled

    @clockEnabled.setter
    def clockEnabled(self, value: bool) -> None:
        self._update("_clock_enabled", bool(value), "widgetBoard/clock/visible", self.clockEnabledChanged)

    @Property(bool, notify=focusEnabledChanged)
    def focusEnabled(self) -> bool:
        return self._focus_enabled

    @focusEnabled.setter
    def focusEnabled(self, value: bool) -> None:
        self._update("_focus_enabled", bool(value), "widgetBoard/focus/visible", self.focusEnabledChanged)

    @Property(bool, notify=notesEnabledChanged)
    def notesEnabled(self) -> bool:
        return self._notes_enabled

    @notesEnabled.setter
    def notesEnabled(self, value: bool) -> None:
        self._update("_notes_enabled", bool(value), "widgetBoard/notes/visible", self.notesEnabledChanged)

    @Property(bool, notify=showGreetingChanged)
    def showGreeting(self) -> bool:
        return self._show_greeting

    @showGreeting.setter
    def showGreeting(self, value: bool) -> None:
        self._update("_show_greeting", bool(value), "appearance/showGreeting", self.showGreetingChanged)

    @Property(bool, notify=compactLayoutChanged)
    def compactLayout(self) -> bool:
        return self._compact_layout

    @compactLayout.setter
    def compactLayout(self, value: bool) -> None:
        self._update("_compact_layout", bool(value), "appearance/compactLayout", self.compactLayoutChanged)

    @Property(bool, notify=showWeekdayChanged)
    def showWeekday(self) -> bool:
        return self._show_weekday

    @showWeekday.setter
    def showWeekday(self, value: bool) -> None:
        self._update("_show_weekday", bool(value), "calendar/showWeekday", self.showWeekdayChanged)

    @Property(str, notify=layoutModeChanged)
    def layoutMode(self) -> str:
        return self._layout_mode

    @layoutMode.setter
    def layoutMode(self, value: str) -> None:
        if value in {"auto", "single", "double"}:
            self._update("_layout_mode", value, "appearance/layoutMode", self.layoutModeChanged)

    @Property(float, notify=cardOpacityChanged)
    def cardOpacity(self) -> float:
        return self._card_opacity

    @cardOpacity.setter
    def cardOpacity(self, value: float) -> None:
        value = round(min(1.0, max(0.55, float(value))), 2)
        self._update("_card_opacity", value, "appearance/cardOpacity", self.cardOpacityChanged)

    @Property(float, notify=tileTransparencyChanged)
    def tileTransparency(self) -> float:
        return self._tile_transparency

    @tileTransparency.setter
    def tileTransparency(self, value: float) -> None:
        value = round(min(1.0, max(0.0, float(value))), 2)
        self._update(
            "_tile_transparency",
            value,
            "appearance/tileTransparency",
            self.tileTransparencyChanged,
        )

    @Property(str, notify=weatherCityChanged)
    def weatherCity(self) -> str:
        return self._weather_city

    @weatherCity.setter
    def weatherCity(self, value: str) -> None:
        value = value.strip() or "武汉市"
        self._update("_weather_city", value, "weather/city", self.weatherCityChanged)

    @Property(str, notify=temperatureUnitChanged)
    def temperatureUnit(self) -> str:
        return self._temperature_unit

    @temperatureUnit.setter
    def temperatureUnit(self, value: str) -> None:
        if value in {"C", "F"}:
            self._update("_temperature_unit", value, "weather/unit", self.temperatureUnitChanged)

    @Property(str, notify=countdownTitleChanged)
    def countdownTitle(self) -> str:
        return self._countdown_title

    @countdownTitle.setter
    def countdownTitle(self, value: str) -> None:
        value = value.strip() or "距离下一个目标"
        self._update("_countdown_title", value, "countdown/title", self.countdownTitleChanged)

    @Property(int, notify=countdownDaysChanged)
    def countdownDays(self) -> int:
        return self._countdown_days

    @countdownDays.setter
    def countdownDays(self, value: int) -> None:
        value = min(9999, max(0, int(value)))
        self._update("_countdown_days", value, "countdown/days", self.countdownDaysChanged)
        self.countdownTargetDate = QDate.currentDate().addDays(value).toString("yyyy-MM-dd")

    @Property(str, notify=countdownTargetDateChanged)
    def countdownTargetDate(self) -> str:
        return self._countdown_target_date

    @countdownTargetDate.setter
    def countdownTargetDate(self, value: str) -> None:
        if QDate.fromString(value, "yyyy-MM-dd").isValid():
            self._update(
                "_countdown_target_date",
                value,
                "countdown/targetDate",
                self.countdownTargetDateChanged,
            )

    @Property(int, notify=countdownTargetHourChanged)
    def countdownTargetHour(self) -> int:
        return self._countdown_target_hour

    @countdownTargetHour.setter
    def countdownTargetHour(self, value: int) -> None:
        value = min(23, max(0, int(value)))
        self._update(
            "_countdown_target_hour",
            value,
            "countdown/targetHour",
            self.countdownTargetHourChanged,
        )

    @Property(str, notify=themeModeChanged)
    def themeMode(self) -> str:
        return self._theme_mode

    @themeMode.setter
    def themeMode(self, value: str) -> None:
        if value in {"Auto", "Light", "Dark"}:
            self._update("_theme_mode", value, "appearance/themeMode", self.themeModeChanged)

    @Property(str, notify=accentColorChanged)
    def accentColor(self) -> str:
        return self._accent_color

    @accentColor.setter
    def accentColor(self, value: str) -> None:
        if len(value) == 7 and value.startswith("#"):
            self._update("_accent_color", value, "appearance/accentColor", self.accentColorChanged)

    @Property(str, notify=backdropEffectChanged)
    def backdropEffect(self) -> str:
        return self._backdrop_effect

    @backdropEffect.setter
    def backdropEffect(self, value: str) -> None:
        value = self._resolve_backdrop_effect(str(value))
        if value in {"mica", "acrylic", "tabbed", "none"}:
            self._update("_backdrop_effect", value, "appearance/backdropEffect", self.backdropEffectChanged)

    @Slot(str, result=bool)
    def widgetVisible(self, widget_name: str) -> bool:
        return {
            "weather": self.weatherEnabled,
            "calendar": self.calendarEnabled,
            "countdown": self.countdownEnabled,
            "clock": self.clockEnabled,
            "focus": self.focusEnabled,
            "notes": self.notesEnabled,
        }.get(widget_name, False)

    @Slot(str, bool)
    def setWidgetVisible(self, widget_name: str, visible: bool) -> None:
        if widget_name == "weather":
            self.weatherEnabled = visible
        elif widget_name == "calendar":
            self.calendarEnabled = visible
        elif widget_name == "countdown":
            self.countdownEnabled = visible
        elif widget_name == "clock":
            self.clockEnabled = visible
        elif widget_name == "focus":
            self.focusEnabled = visible
        elif widget_name == "notes":
            self.notesEnabled = visible

    @Slot()
    def resetDefaults(self) -> None:
        self.weatherEnabled = True
        self.calendarEnabled = True
        self.countdownEnabled = False
        self.clockEnabled = True
        self.focusEnabled = False
        self.notesEnabled = False
        self.showGreeting = True
        self.compactLayout = False
        self.showWeekday = True
        self.layoutMode = "auto"
        self.cardOpacity = 0.88
        self.tileTransparency = 0.86
        self.weatherCity = "武汉市"
        self.temperatureUnit = "C"
        self.countdownTitle = "距离下一个目标"
        self.countdownDays = 12
        self.countdownTargetDate = QDate.currentDate().addDays(12).toString("yyyy-MM-dd")
        self.countdownTargetHour = 18
        self.themeMode = "Auto"
        self.accentColor = "#605ed2"
        self.backdropEffect = self._default_backdrop_effect()


class SettingsWindowController(QObject):
    """Routes every settings request back into the main window."""

    settingsRequested = Signal()

    def __init__(
        self,
        rinui_root: Path,
        settings: AppSettings,
        weather: WeatherService,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._rinui_root = rinui_root
        self._settings = settings
        self._weather = weather
        self._window = None

    @Slot()
    def show(self) -> None:
        self.settingsRequested.emit()


class FloatingShelfController(QObject):
    """Owns the shortcut shelf window and exposes it to the home page."""

    def __init__(
        self,
        rinui_root: Path,
        collection: ShelfCollectionModel,
        shelf_settings: ShelfSettings,
        app_settings: AppSettings,
        settings_window: SettingsWindowController,
        widget_board: QObject | None = None,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._rinui_root = rinui_root
        self._collection = collection
        self._shelf_settings = shelf_settings
        self._app_settings = app_settings
        self._settings_window = settings_window
        self._widget_board = widget_board
        self._windows: dict[str, object] = {}
        self._window_settings: dict[str, ShelfWindowSettings] = {}

    def set_widget_board(self, widget_board: QObject) -> None:
        self._widget_board = widget_board

    @Slot()
    def show(self) -> None:
        self.showBox(self._collection.defaultBoxId)

    @Slot(str)
    def showBox(self, box_id: str) -> None:
        from RinUI import BackdropEffect, RinUIWindow

        if not box_id:
            return
        window = self._windows.get(box_id)
        if window is not None and window.root_window is not None:
            try:
                root = window.root_window
                root.show()
                root.raise_()
                root.requestActivate()
                return
            except RuntimeError:
                self._windows.pop(box_id, None)

        model = self._collection.model_for_box(box_id)
        category = self._collection.category_for_box(box_id)
        window_settings = ShelfWindowSettings(
            self._collection, box_id, self._shelf_settings, self
        )
        window = RinUIWindow(shared_engine=False)
        window.engine.addImportPath(str(self._rinui_root))
        context = window.engine.rootContext()
        context.setContextProperty("shelfCategory", category)
        context.setContextProperty("shelfSettings", window_settings)
        context.setContextProperty("appSettings", self._app_settings)
        context.setContextProperty("settingsWindowBackend", self._settings_window)
        context.setContextProperty("widgetBoardBackend", self._widget_board)
        if category == "文件夹收纳箱":
            context.setContextProperty("folderModel", model)
            context.setContextProperty("folderBackend", model)
            qml_file = "FolderShelf.qml"
        else:
            context.setContextProperty("shortcutModel", model)
            context.setContextProperty("shortcutBackend", model)
            qml_file = "FloatingShelf.qml"
        window.load(Path(__file__).parent / "qml" / qml_file)
        window.setBackdropEffect(BackdropEffect(self._app_settings.backdropEffect))
        self._windows[box_id] = window
        self._window_settings[box_id] = window_settings
        root = window.root_window
        root.destroyed.connect(lambda *_args, bid=box_id: self._forget_window(bid))
        root.show()
        root.raise_()
        root.requestActivate()

    def _forget_window(self, box_id: str) -> None:
        self._windows.pop(box_id, None)
        self._window_settings.pop(box_id, None)


DESKTOP_WIDGET_SIZES = {
    "weather": (336, 196),
    "calendar": (336, 292),
    "countdown": (336, 188),
    "clock": (336, 164),
    "focus": (336, 220),
    "notes": (336, 224),
}

DESKTOP_WIDGET_TITLES = {
    "weather": "天气",
    "calendar": "日历",
    "countdown": "倒计时",
    "clock": "时钟",
    "focus": "专注",
    "notes": "便签",
}

DESKTOP_WIDGET_HORIZONTAL_GAP = 14
DESKTOP_WIDGET_VERTICAL_GAP = 14
DESKTOP_WIDGET_SNAP_DISTANCE = 32
DESKTOP_WIDGET_MAGNET_RADIUS = 120
DESKTOP_WIDGET_GRID_SIZE = 24
DESKTOP_WIDGET_MARGIN = 18


class DesktopWidgetController(QObject):
    """Pins widget tiles onto the desktop as independent acrylic windows."""

    pinnedChanged = Signal()
    lockChanged = Signal()
    stayOnTopChanged = Signal()

    def __init__(
        self,
        rinui_root: Path,
        settings: AppSettings,
        weather: WeatherService,
        settings_window: SettingsWindowController,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._rinui_root = rinui_root
        self._settings = settings
        self._weather = weather
        self._settings_window = settings_window
        self._store = QSettings("FlowWidget", "FlowWidget")
        self._windows: dict[str, object] = {}
        self._items: list[dict] = self._load()

    def _load(self) -> list[dict]:
        raw = self._store.value("desktopWidgets/items", "[]")
        try:
            payload = json.loads(str(raw))
        except (TypeError, ValueError, json.JSONDecodeError):
            return []
        items = []
        if not isinstance(payload, list):
            return []
        for entry in payload:
            if not isinstance(entry, dict):
                continue
            widget_id = str(entry.get("id", ""))
            if widget_id not in DESKTOP_WIDGET_SIZES:
                continue
            default_w, default_h = DESKTOP_WIDGET_SIZES[widget_id]
            items.append(
                {
                    "id": widget_id,
                    "x": int(entry.get("x", 80)),
                    "y": int(entry.get("y", 80)),
                    "width": int(entry.get("width", default_w)),
                    "height": int(entry.get("height", default_h)),
                    "locked": bool(entry.get("locked", False)),
                    "stayOnTop": bool(entry.get("stayOnTop", False)),
                }
            )
        return items

    def _save(self) -> None:
        self._store.setValue("desktopWidgets/items", json.dumps(self._items))

    def _item(self, widget_id: str) -> dict | None:
        for item in self._items:
            if item["id"] == widget_id:
                return item
        return None

    def _widget_dimensions(self, widget_id: str) -> tuple[int, int]:
        default_width, default_height = DESKTOP_WIDGET_SIZES[widget_id]
        item = self._item(widget_id)
        if item is None:
            return default_width, default_height
        return (
            max(1, int(item.get("width", default_width))),
            max(1, int(item.get("height", default_height))),
        )

    @staticmethod
    def _desktop_bounds():
        screens = QGuiApplication.screens()
        if not screens:
            return None
        bounds = screens[0].availableGeometry()
        for screen in screens[1:]:
            bounds = bounds.united(screen.availableGeometry())
        return bounds

    @staticmethod
    def _clamp_position(x: float, y: float, width: int, height: int, bounds) -> tuple[int, int]:
        left = int(bounds.x()) + DESKTOP_WIDGET_MARGIN
        top = int(bounds.y()) + DESKTOP_WIDGET_MARGIN
        right = max(left, int(bounds.x()) + int(bounds.width()) - width - DESKTOP_WIDGET_MARGIN)
        bottom = max(top, int(bounds.y()) + int(bounds.height()) - height - DESKTOP_WIDGET_MARGIN)
        return (
            max(left, min(int(round(x)), right)),
            max(top, min(int(round(y)), bottom)),
        )

    @staticmethod
    def _inside_bounds(x: int, y: int, width: int, height: int, bounds) -> bool:
        return (
            x >= int(bounds.x()) + DESKTOP_WIDGET_MARGIN
            and y >= int(bounds.y()) + DESKTOP_WIDGET_MARGIN
            and x + width <= int(bounds.x()) + int(bounds.width()) - DESKTOP_WIDGET_MARGIN
            and y + height <= int(bounds.y()) + int(bounds.height()) - DESKTOP_WIDGET_MARGIN
        )

    def _is_free(self, widget_id: str, x: int, y: int, width: int, height: int) -> bool:
        for other in self._items:
            if other["id"] == widget_id:
                continue
            other_width, other_height = self._widget_dimensions(other["id"])
            other_x = int(other.get("x", 0))
            other_y = int(other.get("y", 0))
            if (
                x < other_x + other_width
                and x + width > other_x
                and y < other_y + other_height
                and y + height > other_y
            ):
                return False
        return True

    @staticmethod
    def _unique_positions(values: list[tuple[int, str]]) -> list[tuple[int, str]]:
        seen: set[int] = set()
        result: list[tuple[int, str]] = []
        for value, label in values:
            if value in seen:
                continue
            seen.add(value)
            result.append((value, label))
        return result

    def _magnetic_candidates(
        self,
        other: dict,
        width: int,
        height: int,
    ) -> list[tuple[int, int, str]]:
        other_width, other_height = self._widget_dimensions(other["id"])
        other_x = int(other.get("x", 0))
        other_y = int(other.get("y", 0))
        x_alignments = self._unique_positions(
            [
                (other_x, "左边缘"),
                (other_x + other_width - width, "右边缘"),
                (other_x + (other_width - width) // 2, "水平居中"),
            ]
        )
        y_alignments = self._unique_positions(
            [
                (other_y, "顶部"),
                (other_y + other_height - height, "底部"),
                (other_y + (other_height - height) // 2, "垂直居中"),
            ]
        )
        candidates: list[tuple[int, int, str]] = []

        for x, side_label, direction in (
            (other_x + other_width + DESKTOP_WIDGET_HORIZONTAL_GAP, "右侧", "right"),
            (other_x - width - DESKTOP_WIDGET_HORIZONTAL_GAP, "左侧", "left"),
        ):
            for y, alignment_label in y_alignments:
                candidates.append((x, y, direction))

        for y, side_label, direction in (
            (other_y + other_height + DESKTOP_WIDGET_VERTICAL_GAP, "下方", "below"),
            (other_y - height - DESKTOP_WIDGET_VERTICAL_GAP, "上方", "above"),
        ):
            for x, alignment_label in x_alignments:
                candidates.append((x, y, direction))

        return candidates

    def _find_free_grid_position(
        self,
        widget_id: str,
        x: int,
        y: int,
        width: int,
        height: int,
        bounds,
    ) -> tuple[int, int]:
        anchor_x = int(bounds.x()) + DESKTOP_WIDGET_MARGIN
        anchor_y = int(bounds.y()) + DESKTOP_WIDGET_MARGIN
        grid = DESKTOP_WIDGET_GRID_SIZE
        grid_x = anchor_x + int(round((x - anchor_x) / grid)) * grid
        grid_y = anchor_y + int(round((y - anchor_y) / grid)) * grid
        grid_x, grid_y = self._clamp_position(grid_x, grid_y, width, height, bounds)
        if self._is_free(widget_id, grid_x, grid_y, width, height):
            return grid_x, grid_y

        for radius in range(1, 48):
            offsets: list[tuple[int, int]] = []
            for delta in range(-radius, radius + 1):
                offsets.extend(
                    [
                        (delta, -radius),
                        (delta, radius),
                        (-radius, delta),
                        (radius, delta),
                    ]
                )
            for offset_x, offset_y in offsets:
                candidate_x, candidate_y = self._clamp_position(
                    grid_x + offset_x * grid,
                    grid_y + offset_y * grid,
                    width,
                    height,
                    bounds,
                )
                if not self._is_free(widget_id, candidate_x, candidate_y, width, height):
                    continue
                return candidate_x, candidate_y
        return grid_x, grid_y

    def _resolve_placement(self, widget_id: str, x: float, y: float) -> dict:
        width, height = self._widget_dimensions(widget_id)
        bounds = self._desktop_bounds()
        if bounds is None:
            return {
                "x": int(round(x)),
                "y": int(round(y)),
                "previewX": int(round(x)),
                "previewY": int(round(y)),
                "width": width,
                "height": height,
                "snapped": False,
                "magnetized": False,
                "tidied": False,
                "targetId": "",
                "direction": "",
                "message": "释放后自动整理",
            }

        raw_x, raw_y = self._clamp_position(x, y, width, height, bounds)
        best_snap: tuple[float, int, int, int, str] | None = None
        best_magnetic: tuple[float, int, int, int, str] | None = None
        snap_direction = ""
        magnetic_direction = ""
        candidate_order = 0
        for other in self._items:
            if other["id"] == widget_id:
                continue
            for candidate_x, candidate_y, direction in self._magnetic_candidates(
                other, width, height
            ):
                candidate_order += 1
                if not self._inside_bounds(candidate_x, candidate_y, width, height, bounds):
                    continue
                if not self._is_free(widget_id, candidate_x, candidate_y, width, height):
                    continue
                distance = abs(candidate_x - x) + abs(candidate_y - y)
                if distance > DESKTOP_WIDGET_MAGNET_RADIUS:
                    continue
                score = (distance, candidate_order, candidate_x, candidate_y, other["id"])
                if best_magnetic is None or score < best_magnetic:
                    best_magnetic = score
                    magnetic_direction = direction
                if distance <= DESKTOP_WIDGET_SNAP_DISTANCE and (
                    best_snap is None or score < best_snap
                ):
                    best_snap = score
                    snap_x, snap_y = candidate_x, candidate_y
                    snap_target = other["id"]
                    snap_direction = direction

        if best_snap is not None:
            return {
                "x": int(snap_x),
                "y": int(snap_y),
                "previewX": int(snap_x),
                "previewY": int(snap_y),
                "width": width,
                "height": height,
                "snapped": True,
                "magnetized": True,
                "tidied": True,
                "targetId": snap_target,
                "direction": snap_direction,
                "message": "已对齐",
            }

        safe_x, safe_y = self._find_free_grid_position(
            widget_id, raw_x, raw_y, width, height, bounds
        )
        raw_is_free = self._is_free(widget_id, raw_x, raw_y, width, height)
        if best_magnetic is not None:
            magnet_distance, _, magnet_x, magnet_y, magnet_target = best_magnetic
            influence = max(
                0.0,
                min(1.0, 1.0 - magnet_distance / DESKTOP_WIDGET_MAGNET_RADIUS),
            )
            influence *= influence
            preview_x = int(round(raw_x + (magnet_x - raw_x) * influence))
            preview_y = int(round(raw_y + (magnet_y - raw_y) * influence))
            return {
                "x": int(safe_x),
                "y": int(safe_y),
                "previewX": preview_x,
                "previewY": preview_y,
                "width": width,
                "height": height,
                "snapped": False,
                "magnetized": True,
                "tidied": False,
                "targetId": magnet_target,
                "direction": magnetic_direction,
                "message": "靠近边缘自动吸附",
            }
        return {
            "x": int(safe_x),
            "y": int(safe_y),
            "previewX": int(safe_x),
            "previewY": int(safe_y),
            "width": width,
            "height": height,
            "snapped": False,
            "magnetized": False,
            "tidied": (safe_x, safe_y) != (raw_x, raw_y) or not raw_is_free,
            "targetId": "",
            "direction": "",
            "message": "释放后自动整理",
        }

    @Slot(str, result=bool)
    def isPinned(self, widget_id: str) -> bool:
        return self._item(widget_id) is not None

    @Slot(str, result=bool)
    def isLocked(self, widget_id: str) -> bool:
        item = self._item(widget_id)
        return bool(item and item.get("locked"))

    @Slot(str, result=bool)
    def isStayOnTop(self, widget_id: str) -> bool:
        item = self._item(widget_id)
        return bool(item and item.get("stayOnTop"))

    @Slot(str, result=str)
    def titleFor(self, widget_id: str) -> str:
        if widget_id == "countdown":
            return self._settings.countdownTitle
        return DESKTOP_WIDGET_TITLES.get(widget_id, widget_id)

    @Slot(str, float, float, result="QVariantMap")
    def previewPlacement(self, widget_id: str, x: float, y: float) -> dict:
        if widget_id not in DESKTOP_WIDGET_SIZES:
            return {}
        return self._resolve_placement(widget_id, x, y)

    @Slot(str, float, float)
    def pinAt(self, widget_id: str, x: float, y: float) -> None:
        if widget_id not in DESKTOP_WIDGET_SIZES:
            return
        item = self._item(widget_id)
        if item is not None and item.get("locked"):
            return
        placement = self._resolve_placement(widget_id, x, y)
        width = int(placement["width"])
        height = int(placement["height"])
        if item is None:
            item = {
                "id": widget_id,
                "x": int(placement["x"]),
                "y": int(placement["y"]),
                "width": width,
                "height": height,
                "locked": False,
                "stayOnTop": False,
            }
            self._items.append(item)
        else:
            item["x"] = int(placement["x"])
            item["y"] = int(placement["y"])
        self._save()
        self.pinnedChanged.emit()
        self._show_item(item, activate=True)

    @Slot(str)
    def pin(self, widget_id: str) -> None:
        item = self._item(widget_id)
        if item is not None:
            self._show_item(item, activate=True)
            return
        self.pinAt(widget_id, 96, 96)

    @Slot(str)
    def unpin(self, widget_id: str) -> None:
        self._items = [item for item in self._items if item["id"] != widget_id]
        self._save()
        self.pinnedChanged.emit()
        window = self._windows.pop(widget_id, None)
        if window is None:
            return
        root = getattr(window, "root_window", None)
        if root is not None:
            try:
                root.setProperty("allowClose", True)
                root.close()
            except RuntimeError:
                pass

    @Slot(str, bool)
    def setLocked(self, widget_id: str, locked: bool) -> None:
        item = self._item(widget_id)
        if item is None:
            return
        item["locked"] = bool(locked)
        self._save()
        self.lockChanged.emit()
        window = self._windows.get(widget_id)
        if window is None:
            return
        root = getattr(window, "root_window", None)
        if root is None:
            return
        try:
            root.setProperty("locked", bool(locked))
        except RuntimeError:
            pass

    @Slot(str, bool)
    def setStayOnTop(self, widget_id: str, stay_on_top: bool) -> None:
        item = self._item(widget_id)
        if item is None:
            return
        item["stayOnTop"] = bool(stay_on_top)
        self._save()
        self.stayOnTopChanged.emit()
        window = self._windows.get(widget_id)
        if window is None:
            return
        root = getattr(window, "root_window", None)
        if root is None:
            return
        try:
            root.setProperty("stayOnTop", bool(stay_on_top))
            self._apply_window_layer(root, bool(stay_on_top))
        except RuntimeError:
            pass

    @Slot(str)
    def ensureLayer(self, widget_id: str) -> None:
        item = self._item(widget_id)
        window = self._windows.get(widget_id)
        if item is None or window is None:
            return
        root = getattr(window, "root_window", None)
        if root is None:
            return
        try:
            self._apply_window_layer(root, bool(item.get("stayOnTop")))
        except RuntimeError:
            pass

    @Slot(str, int, int, int, int)
    def saveGeometry(self, widget_id: str, x: int, y: int, width: int, height: int) -> None:
        item = self._item(widget_id)
        if item is None or item.get("locked"):
            return
        item["x"] = int(x)
        item["y"] = int(y)
        item["width"] = int(width)
        item["height"] = int(height)
        self._save()

    @Slot()
    def restoreAll(self) -> None:
        for item in list(self._items):
            self._show_item(item, activate=False)

    def _show_item(self, item: dict, activate: bool) -> None:
        from RinUI import BackdropEffect, RinUIWindow

        widget_id = item["id"]
        window = self._windows.get(widget_id)
        if window is not None and getattr(window, "root_window", None) is not None:
            try:
                root = window.root_window
                root.setX(item["x"])
                root.setY(item["y"])
                root.setProperty("locked", bool(item.get("locked")))
                root.setProperty("stayOnTop", bool(item.get("stayOnTop")))
                self._apply_window_layer(root, bool(item.get("stayOnTop")))
                root.show()
                return
            except RuntimeError:
                self._windows.pop(widget_id, None)

        window = RinUIWindow(shared_engine=False)
        window.engine.addImportPath(str(self._rinui_root))
        context = window.engine.rootContext()
        context.setContextProperty("appSettings", self._settings)
        context.setContextProperty("weatherBackend", self._weather)
        context.setContextProperty("settingsWindowBackend", self._settings_window)
        context.setContextProperty("desktopWidgetBackend", self)
        context.setContextProperty("widgetId", widget_id)
        window.load(Path(__file__).parent / "qml" / "DesktopWidget.qml")
        window.setBackdropEffect(BackdropEffect(self._settings.backdropEffect))
        root = window.root_window
        root.setX(item["x"])
        root.setY(item["y"])
        root.setWidth(item["width"])
        root.setHeight(item["height"])
        root.setProperty("locked", bool(item.get("locked")))
        root.setProperty("stayOnTop", bool(item.get("stayOnTop")))
        root.setProperty("appearAnimated", bool(activate))
        root.destroyed.connect(lambda *_args, wid=widget_id: self._on_closed(wid))
        self._windows[widget_id] = window
        root.show()
        self._apply_window_layer(root, bool(item.get("stayOnTop")))

    @classmethod
    def _widget_flags(cls, stay_on_top: bool):
        flags = Qt.Tool | Qt.FramelessWindowHint
        if stay_on_top:
            return flags | Qt.WindowStaysOnTopHint
        return flags | Qt.WindowStaysOnBottomHint

    @classmethod
    def _apply_window_layer(cls, root, stay_on_top: bool) -> None:
        root.setFlags(cls._widget_flags(stay_on_top))
        if sys.platform != "win32":
            return
        try:
            hwnd = int(root.winId())
        except (RuntimeError, TypeError, ValueError):
            return
        gwl_exstyle = -20
        ws_ex_toolwindow = 0x00000080
        ws_ex_appwindow = 0x00040000
        style = ctypes.windll.user32.GetWindowLongPtrW(hwnd, gwl_exstyle)
        ctypes.windll.user32.SetWindowLongPtrW(
            hwnd, gwl_exstyle, (style | ws_ex_toolwindow) & ~ws_ex_appwindow
        )
        hwnd_insert = -1 if stay_on_top else 1  # HWND_TOPMOST or HWND_BOTTOM
        ctypes.windll.user32.SetWindowPos(
            hwnd,
            hwnd_insert,
            0,
            0,
            0,
            0,
            0x0001 | 0x0002 | 0x0010,
        )

    def _on_closed(self, widget_id: str) -> None:
        self._windows.pop(widget_id, None)
        if self._item(widget_id) is None:
            return
        self._items = [item for item in self._items if item["id"] != widget_id]
        self._save()
        self.pinnedChanged.emit()


class HomeWindowController(QObject):
    """Owns the first window shown when FlowWidget starts."""

    def __init__(
        self,
        rinui_root: Path,
        model: ShortcutModel,
        collection: ShelfCollectionModel,
        app_settings: AppSettings,
        weather: WeatherService,
        shelf: FloatingShelfController,
        widget_board: WidgetBoardController,
        settings_window: SettingsWindowController,
        desktop_widgets: DesktopWidgetController,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._rinui_root = rinui_root
        self._model = model
        self._collection = collection
        self._app_settings = app_settings
        self._weather = weather
        self._shelf = shelf
        self._widget_board = widget_board
        self._settings_window = settings_window
        self._desktop_widgets = desktop_widgets
        self._window = None

    @Slot()
    def open_settings(self) -> None:
        if self._window is None or self._window.root_window is None:
            return
        root = self._window.root_window
        root.show()
        root.raise_()
        root.requestActivate()
        root.openSettings()

    @Slot()
    def show(self) -> None:
        from RinUI import BackdropEffect, RinUIWindow

        if self._window is not None and self._window.root_window is not None:
            try:
                root = self._window.root_window
                root.show()
                root.raise_()
                root.requestActivate()
                return
            except RuntimeError:
                self._window = None

        self._window = RinUIWindow(shared_engine=False)
        self._window.engine.addImportPath(str(self._rinui_root))
        context = self._window.engine.rootContext()
        context.setContextProperty("shortcutModel", self._model)
        context.setContextProperty("shelfCollectionModel", self._collection)
        context.setContextProperty("appSettings", self._app_settings)
        context.setContextProperty("weatherBackend", self._weather)
        context.setContextProperty("shelfBackend", self._shelf)
        context.setContextProperty("widgetBoardBackend", self._widget_board)
        context.setContextProperty("settingsWindowBackend", self._settings_window)
        context.setContextProperty("desktopWidgetBackend", self._desktop_widgets)
        self._window.load(Path(__file__).parent / "qml" / "HomePage.qml")
        self._window.setBackdropEffect(BackdropEffect(self._app_settings.backdropEffect))
        root = self._window.root_window
        root.destroyed.connect(lambda *_: setattr(self, "_window", None))
        root.show()
        root.raise_()
        root.requestActivate()


class WidgetBoardController(QObject):
    """Lazily owns the separate RinUI window used for widget cards."""

    def __init__(
        self,
        rinui_root: Path,
        settings: AppSettings,
        weather: WeatherService,
        settings_window: SettingsWindowController,
        desktop_widgets: DesktopWidgetController,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._rinui_root = rinui_root
        self._window = None
        self._settings = settings
        self._weather = weather
        self._settings_window = settings_window
        self._desktop_widgets = desktop_widgets

    @Slot()
    def show(self) -> None:
        from RinUI import BackdropEffect, RinUIWindow

        if self._window is not None and self._window.root_window is not None:
            try:
                root = self._window.root_window
                root.show()
                root.raise_()
                root.requestActivate()
                return
            except RuntimeError:
                # The QML window may have been destroyed after the user closed it.
                self._window = None

        self._window = RinUIWindow(shared_engine=False)
        self._window.engine.addImportPath(str(self._rinui_root))
        self._window.engine.rootContext().setContextProperty("appSettings", self._settings)
        self._window.engine.rootContext().setContextProperty("weatherBackend", self._weather)
        self._window.engine.rootContext().setContextProperty(
            "settingsWindowBackend", self._settings_window
        )
        self._window.engine.rootContext().setContextProperty(
            "desktopWidgetBackend", self._desktop_widgets
        )
        self._window.load(Path(__file__).parent / "qml" / "WidgetBoard.qml")
        self._window.setBackdropEffect(BackdropEffect(self._settings.backdropEffect))
        root = self._window.root_window
        root.destroyed.connect(lambda *_: setattr(self, "_window", None))
        root.show()
        root.raise_()
        root.requestActivate()


def _rinui_root() -> Path:
    configured = os.environ.get("POGGET_RINUI_PATH", "").strip()
    if configured:
        candidate = Path(configured).expanduser()
        # Accept either the Rin-UI project root or its inner RinUI package.
        if candidate.name == "RinUI" and (candidate / "__init__.py").is_file():
            candidate = candidate.parent
        return candidate.resolve()
    return (Path(__file__).resolve().parent / "Rin-UI-master").resolve()


def _prepare_qt_surface() -> None:
    fmt = QSurfaceFormat.defaultFormat()
    fmt.setAlphaBufferSize(8)
    QSurfaceFormat.setDefaultFormat(fmt)
    QQuickWindow.setDefaultAlphaBuffer(True)
    if sys.platform == "win32":
        QQuickWindow.setGraphicsApi(QSGRendererInterface.GraphicsApi.Direct3D11)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    _prepare_qt_surface()
    app = QApplication(sys.argv)
    app.setOrganizationName("FlowWidget")
    app.setApplicationName("FlowWidget")
    rinui_root = _rinui_root()
    if not (rinui_root / "RinUI" / "__init__.py").is_file():
        raise RuntimeError(
            "RinUI was not found next to the application. "
            "Set POGGET_RINUI_PATH to the Rin-UI project root or RinUI package directory."
        )

    if str(rinui_root) not in sys.path:
        sys.path.insert(0, str(rinui_root))

    shelf_collection = ShelfCollectionModel()
    model = shelf_collection.model_for_box(shelf_collection.defaultBoxId)
    shelf_settings = ShelfSettings()
    app_settings = AppSettings()
    weather = WeatherService(app_settings)
    settings_window = SettingsWindowController(rinui_root, app_settings, weather)
    desktop_widgets = DesktopWidgetController(
        rinui_root, app_settings, weather, settings_window
    )
    widget_board = WidgetBoardController(
        rinui_root, app_settings, weather, settings_window, desktop_widgets
    )
    shelf = FloatingShelfController(
        rinui_root,
        shelf_collection,
        shelf_settings,
        app_settings,
        settings_window,
        widget_board,
    )
    home = HomeWindowController(
        rinui_root,
        model,
        shelf_collection,
        app_settings,
        weather,
        shelf,
        widget_board,
        settings_window,
        desktop_widgets,
    )
    settings_window.settingsRequested.connect(home.open_settings)
    home.show()
    QTimer.singleShot(200, desktop_widgets.restoreAll)
    return app.exec()
