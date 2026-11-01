import ctypes
import platform
import sys
import time

import darkdetect
from PySide6.QtCore import QObject, QThread, Signal, Slot

from .config import (
    DEFAULT_CONFIG,
    BackdropEffect,
    RinConfig,
    is_win10,
    is_win11,
    is_windows,
)


def check_darkdetect_support():
    system = platform.system()
    if system == "Darwin":
        mac_ver = platform.mac_ver()[0]
        major, minor, *_ = map(int, mac_ver.split("."))
        return (major == 10 and minor >= 14) or major > 10

    if system == "Windows":
        return platform.release() >= "10"
    return False


ACCENT_STATES = {"acrylic": 3, "mica": 2, "tabbed": 4, "none": 0}

ACCENT_SUPPORT = {
    "acrylic": is_win10(),
    "mica": is_win11(),
    "tabbed": is_win10(),
    "none": True,
}


class ACCENT_POLICY(ctypes.Structure):
    _fields_ = [
        ("AccentState", ctypes.c_int),
        ("AccentFlags", ctypes.c_int),
        ("GradientColor", ctypes.c_int),
        ("AnimationId", ctypes.c_int),
    ]


class WINDOWCOMPOSITIONATTRIBDATA(ctypes.Structure):
    _fields_ = [
        ("Attrib", ctypes.c_int),
        ("pvData", ctypes.c_void_p),
        ("cbData", ctypes.c_size_t),
    ]


class MARGINS(ctypes.Structure):
    _fields_ = [
        ("cxLeftWidth", ctypes.c_int),
        ("cxRightWidth", ctypes.c_int),
        ("cyTopHeight", ctypes.c_int),
        ("cyBottomHeight", ctypes.c_int),
    ]


# DWM system backdrop types (Windows 11)
DWMSBT_AUTO = 0
DWMSBT_NONE = 1
DWMSBT_MAINWINDOW = 2  # Mica
DWMSBT_TRANSIENTWINDOW = 3  # Acrylic
DWMSBT_TABBEDWINDOW = 4  # Mica Alt

ACCENT_ENABLE_ACRYLICBLURBEHIND = 4
DWMWA_COLOR_NONE = 0xFFFFFFFE


class ThemeListener(QThread):
    """
    监听系统颜色模式
    """

    themeChanged = Signal(str)

    def run(self):
        last_theme = darkdetect.theme()
        while True:
            current_theme = darkdetect.theme()
            if current_theme != last_theme:
                last_theme = current_theme
                self.themeChanged.emit(current_theme)
                print(f"Theme changed: {current_theme}")
            time.sleep(1)

    def stop(self):
        self.terminate()


class ThemeManager(QObject):
    themeChanged = Signal(str)
    backdropChanged = Signal(str)
    windows = []  # 窗口句柄们（
    tile_windows = set()
    tile_window_objects = {}
    _instance = None

    # DWM 常量保持不变
    DWMWA_USE_IMMERSIVE_DARK_MODE = 20
    DWMWA_WINDOW_CORNER_PREFERENCE = 33
    DWMWA_NCRENDERING_POLICY = 2
    DWMNCRENDERINGPOLICY_ENABLED = 2
    DWMWA_SYSTEMBACKDROP_TYPE = 38
    DWMWA_BORDER_COLOR = 34
    DWMWA_CAPTION_COLOR = 35
    DWMWA_TEXT_COLOR = 36
    WCA_ACCENT_POLICY = 19

    # 圆角
    DWMWCP_DEFAULT = 0
    DWMWCP_DONOTROUND = 1
    DWMWCP_ROUND = 2
    DWMWCP_ROUNDSMALL = 3

    def clean_up(self):
        """
        清理资源并停止主题监听。
        """
        if self.listener:
            RinConfig.save_config()
            print("Save config.")
            self.listener.stop()
            self.listener.wait()  # 等待线程结束
            print("Theme listener stopped.")

    def __new__(cls, *args, **kwargs):
        """
        单例管理，共享主题状态
        :param args:
        :param kwargs:
        """
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if hasattr(self, "_initialized") and self._initialized:
            return
        self._initialized = True
        super().__init__()
        self.theme_dict = {"Light": 0, "Dark": 1}

        self.listener = None  # 监听线程
        self.current_theme = DEFAULT_CONFIG["theme"]["current_theme"]  # 当前主题
        self.is_darkdetect_supported = check_darkdetect_support()

        try:
            self.current_theme = RinConfig["theme"]["current_theme"]
        except Exception as e:
            print(f"Failed to load config because of {e}, using default config")

        self.start_listener()

    def start_listener(self):
        if not self.is_darkdetect_supported:
            print("darkdetect not supported on this platform")
            return
        self.listener = ThemeListener()
        self.listener.themeChanged.connect(self._handle_system_theme)
        self.listener.start()

    def set_window(self, window):  # 绑定窗口句柄
        hwnd = int(window.winId())
        if hwnd not in self.windows:
            self.windows.append(hwnd)
        if bool(window.property("isTileWindow")):
            self.tile_windows.add(hwnd)
            self.tile_window_objects[hwnd] = window
        print(f"Window handle set: {hwnd}")

    def _handle_system_theme(self):
        if self.current_theme == "Auto":
            self._update_window_theme()
            self.themeChanged.emit(self._actual_theme())
        else:
            # 保持当前背景效果不变
            self._update_window_theme()

    @Slot(str)
    def apply_backdrop_effect(self, effect_type: str):
        """
        应用背景效果
        :param effect_type: str, 背景效果类型（acrylic, mica, tabbed, none）
        """
        effect_type = self._resolve_backdrop_effect(effect_type)
        self._update_window_theme()
        if not is_windows() or not self.windows:
            print(f'Cannot apply effect "{effect_type}" on this platform')
            return -2  # 非 windows或未绑定窗口
        self.backdropChanged.emit(effect_type)

        accent_state = ACCENT_STATES.get(effect_type, 0)
        if not ACCENT_SUPPORT.get(effect_type, False):
            print(f'Effect "{effect_type}" not supported on this platform')
            return -1  # 效果不支持

        for hwnd in self.windows:
            if hwnd in self.tile_windows:
                if effect_type == BackdropEffect.None_.value:
                    self._clear_system_backdrop(hwnd)
                else:
                    self._apply_tile_acrylic(hwnd)
                continue
            if effect_type == BackdropEffect.None_.value:
                self._clear_system_backdrop(hwnd)
                continue
            self._extend_frame(hwnd)
            if effect_type == BackdropEffect.Acrylic.value:
                if is_win11():
                    self._apply_system_backdrop(hwnd, DWMSBT_TRANSIENTWINDOW)
                else:
                    self._apply_win10_effect(effect_type, hwnd)
            elif is_win11():
                backdrop = accent_state if accent_state in (
                    DWMSBT_MAINWINDOW,
                    DWMSBT_TRANSIENTWINDOW,
                    DWMSBT_TABBEDWINDOW,
                ) else DWMSBT_TRANSIENTWINDOW
                self._apply_system_backdrop(hwnd, backdrop)

        RinConfig["backdrop_effect"] = effect_type
        # print(
        #     f"Applied \"{effect_type.strip().capitalize()}\" effect with "
        #     f"{platform.system() + '11' if is_win11() else '10'}"
        # )
        return 0  # 成功

    def _extend_frame(self, hwnd: int) -> None:
        margins = MARGINS(-1, -1, -1, -1)
        ctypes.windll.dwmapi.DwmExtendFrameIntoClientArea(
            hwnd, ctypes.byref(margins)
        )

    def _set_immersive_dark_mode(self, hwnd: int) -> None:
        dark_mode = ctypes.c_int(self.theme_dict[self._actual_theme()])
        ctypes.windll.dwmapi.DwmSetWindowAttribute(
            hwnd,
            self.DWMWA_USE_IMMERSIVE_DARK_MODE,
            ctypes.byref(dark_mode),
            ctypes.sizeof(dark_mode),
        )

    def _apply_system_backdrop(self, hwnd: int, backdrop_type: int) -> None:
        self._set_immersive_dark_mode(hwnd)
        self._extend_frame(hwnd)
        backdrop = ctypes.c_int(backdrop_type)
        ctypes.windll.dwmapi.DwmSetWindowAttribute(
            hwnd,
            self.DWMWA_SYSTEMBACKDROP_TYPE,
            ctypes.byref(backdrop),
            ctypes.sizeof(backdrop),
        )
        transparent_color = ctypes.c_int(DWMWA_COLOR_NONE)
        ctypes.windll.dwmapi.DwmSetWindowAttribute(
            hwnd,
            self.DWMWA_CAPTION_COLOR,
            ctypes.byref(transparent_color),
            ctypes.sizeof(transparent_color),
        )
        ctypes.windll.dwmapi.DwmSetWindowAttribute(
            hwnd,
            self.DWMWA_BORDER_COLOR,
            ctypes.byref(transparent_color),
            ctypes.sizeof(transparent_color),
        )

    def _clear_system_backdrop(self, hwnd: int) -> None:
        if is_win11():
            none_backdrop = ctypes.c_int(DWMSBT_NONE)
            ctypes.windll.dwmapi.DwmSetWindowAttribute(
                hwnd,
                self.DWMWA_SYSTEMBACKDROP_TYPE,
                ctypes.byref(none_backdrop),
                ctypes.sizeof(none_backdrop),
            )
        accent = ACCENT_POLICY()
        accent.AccentState = 0
        data = WINDOWCOMPOSITIONATTRIBDATA()
        data.Attrib = self.WCA_ACCENT_POLICY
        data.pvData = ctypes.cast(ctypes.pointer(accent), ctypes.c_void_p)
        data.cbData = ctypes.sizeof(accent)
        try:
            ctypes.windll.user32.SetWindowCompositionAttribute(
                hwnd, ctypes.byref(data)
            )
        except Exception:
            pass

    def _apply_tile_acrylic(self, hwnd: int) -> None:
        """Acrylic for floating shelves: real DWM blur that stays put when unfocused."""
        if is_win11():
            # Qt Quick uses DirectComposition. The old ACCENT_ENABLE_ACRYLICBLURBEHIND
            # path does not composite through that surface, so the shelf looked solid.
            # Native Win11 acrylic (DWMSBT_TRANSIENTWINDOW) does; inactive greying is
            # blocked in the native event filter via WM_NCACTIVATE.
            self._apply_system_backdrop(hwnd, DWMSBT_TRANSIENTWINDOW)
            return
        self._apply_win32_acrylic(hwnd)

    def _apply_win32_acrylic(self, hwnd: int) -> None:
        accent = ACCENT_POLICY()
        accent.AccentState = ACCENT_ENABLE_ACRYLICBLURBEHIND
        accent.AccentFlags = 0x20 | 0x40 | 0x80 | 0x100
        window = self.tile_window_objects.get(hwnd)
        try:
            transparency = float(window.property("tileTransparency"))
        except (TypeError, ValueError, RuntimeError, AttributeError):
            transparency = 0.86
        transparency = min(1.0, max(0.0, transparency))
        alpha = round(4 + ((1.0 - transparency) ** 2) * 247)
        tint_rgb = 0x000000 if self.is_dark_theme() else 0xFFFFFF
        accent.GradientColor = (alpha << 24) | tint_rgb
        data = WINDOWCOMPOSITIONATTRIBDATA()
        data.Attrib = self.WCA_ACCENT_POLICY
        data.pvData = ctypes.cast(ctypes.pointer(accent), ctypes.c_void_p)
        data.cbData = ctypes.sizeof(accent)
        try:
            ctypes.windll.user32.SetWindowCompositionAttribute(
                hwnd, ctypes.byref(data)
            )
        except Exception as err:
            print(f"Failed to apply tile acrylic: {err}")

    @staticmethod
    def _resolve_backdrop_effect(effect_type: str) -> str:
        """Fall back only when the requested Windows material is unavailable."""
        if effect_type == BackdropEffect.Mica.value and not ACCENT_SUPPORT["mica"]:
            return (
                BackdropEffect.Acrylic.value
                if ACCENT_SUPPORT["acrylic"]
                else BackdropEffect.None_.value
            )
        if effect_type == BackdropEffect.Tabbed.value and not ACCENT_SUPPORT["tabbed"]:
            return (
                BackdropEffect.Acrylic.value
                if ACCENT_SUPPORT["acrylic"]
                else BackdropEffect.None_.value
            )
        return effect_type

    def _apply_win10_effect(self, effect_type, hwnd):
        """
        应用 Windows 10 背景效果
        :param effect_type: str, 背景效果类型（acrylic, tabbed(actually blur)
        """
        backdrop_color = RinConfig["win10_feat"][
            "backdrop_dark" if self.is_dark_theme() else "backdrop_light"
        ]

        accent = ACCENT_POLICY()
        accent.AccentState = ACCENT_STATES[effect_type]
        accent.AccentFlags = 2
        accent.GradientColor = backdrop_color
        data = WINDOWCOMPOSITIONATTRIBDATA()
        data.Attrib = self.WCA_ACCENT_POLICY
        data.pvData = ctypes.cast(ctypes.pointer(accent), ctypes.c_void_p)
        data.cbData = ctypes.sizeof(accent)

        try:
            set_window_composition = ctypes.windll.user32.SetWindowCompositionAttribute
            set_window_composition(hwnd, ctypes.byref(data))
        except Exception as e:
            print(f"Failed to apply acrylic on Win10: {e}")

    def apply_window_effects(self):  # 启用圆角阴影
        if sys.platform != "win32" or not self.windows:
            return

        dwm = ctypes.windll.dwmapi

        # 启用非客户端渲染策略（让窗口边框具备阴影）
        ncrp = ctypes.c_int(self.DWMNCRENDERINGPOLICY_ENABLED)
        for hwnd in self.windows:
            dwm.DwmSetWindowAttribute(
                hwnd,
                self.DWMWA_NCRENDERING_POLICY,
                ctypes.byref(ncrp),
                ctypes.sizeof(ncrp),
            )

            # 启用圆角效果
            corner_preference = ctypes.c_int(self.DWMWCP_ROUND)
            dwm.DwmSetWindowAttribute(
                hwnd,
                self.DWMWA_WINDOW_CORNER_PREFERENCE,
                ctypes.byref(corner_preference),
                ctypes.sizeof(corner_preference),
            )
        # print("Enabled Rounded and Shadows")

    def _update_window_theme(self):  # 更新窗口的颜色模式
        if sys.platform != "win32" or not self.windows:
            return
        actual_theme = self._actual_theme()
        effect = RinConfig["backdrop_effect"] or BackdropEffect.None_.value
        for hwnd in self.windows:
            if hwnd in self.tile_windows:
                if effect == BackdropEffect.None_.value:
                    self._clear_system_backdrop(hwnd)
                else:
                    self._apply_tile_acrylic(hwnd)
                continue
            if is_win11():
                ctypes.windll.dwmapi.DwmSetWindowAttribute(
                    hwnd,
                    self.DWMWA_USE_IMMERSIVE_DARK_MODE,
                    ctypes.byref(ctypes.c_int(self.theme_dict[actual_theme])),
                    ctypes.sizeof(ctypes.c_int),
                )
            elif (
                is_win10()
                and effect == BackdropEffect.Acrylic.value
            ):
                self._apply_win10_effect(effect, hwnd)
            else:
                print(f"Cannot apply backdrop on {platform.system()}")

        # print(f"Window theme updated to {actual_theme}")

    def is_dark_theme(self):
        """是否为暗黑主题"""
        return self._actual_theme() == "Dark"

    def _actual_theme(self):
        """实际应用的主题"""
        if self.current_theme == "Auto":
            return (
                darkdetect.theme() or "Light"
                if self.is_darkdetect_supported
                else "Light"
            )
        return self.current_theme

    @Slot(str)
    def toggle_theme(self, theme: str):  # 切换主题
        if theme not in ["Auto", "Light", "Dark"]:  # 三状态
            return
        if self.current_theme != theme:
            print(f"Switching to '{theme}' theme")
            self.current_theme = theme
            RinConfig["theme"]["current_theme"] = theme
            self._update_window_theme()
            self.themeChanged.emit(self._actual_theme())

    @Slot(result=str)
    def get_theme(self):
        return self._actual_theme()

    @Slot(result=str)
    def get_theme_name(self):
        """获取当前主题名称"""
        return self.current_theme

    @Slot(result=str)
    def get_backdrop_effect(self):
        """获取当前背景效果"""
        return RinConfig["backdrop_effect"]

    @Slot(str)
    def set_theme_color(self, color):
        """设置当前主题颜色"""
        RinConfig["theme_color"] = color
        RinConfig.save_config()

    @Slot(result=str)
    def get_theme_color(self):
        """获取当前主题颜色"""
        return RinConfig["theme_color"]
