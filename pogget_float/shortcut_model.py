from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PySide6.QtCore import (
    QAbstractListModel,
    QFileInfo,
    QModelIndex,
    QObject,
    Property,
    QStandardPaths,
    QUrl,
    Qt,
    Signal,
    Slot,
)
from PySide6.QtGui import QDesktopServices, QIcon, QPainter, QPixmap, QRegion
from PySide6.QtWidgets import QFileIconProvider


@dataclass(frozen=True)
class Shortcut:
    path: str
    name: str
    icon_source: str
    restore_path: str = ""


class ShortcutModel(QAbstractListModel):
    NameRole = Qt.UserRole + 1
    PathRole = Qt.UserRole + 2
    IconRole = Qt.UserRole + 3
    RestoreRole = Qt.UserRole + 4

    shortcutsChanged = Signal()

    def __init__(
        self,
        parent: QObject | None = None,
        state_file: Path | None = None,
        archive_dir: Path | None = None,
    ) -> None:
        super().__init__(parent)
        self._items: list[Shortcut] = []
        self._icon_provider = QFileIconProvider()
        self._icon_dir = Path(tempfile.gettempdir()) / "pogget-float-icons"
        self._icon_dir.mkdir(parents=True, exist_ok=True)
        self._data_dir = Path(
            os.environ.get(
                "LOCALAPPDATA",
                QStandardPaths.writableLocation(QStandardPaths.AppLocalDataLocation),
            )
        ) / "FlowWidget"
        self._data_dir.mkdir(parents=True, exist_ok=True)
        self._state_file = state_file or (self._data_dir / "shortcuts.json")
        self._state_file.parent.mkdir(parents=True, exist_ok=True)
        self._archive_dir = archive_dir or (self._data_dir / "shortcuts")
        self._load_items()

    def roleNames(self) -> dict[int, QByteArray]:  # type: ignore[name-defined]
        return {
            self.NameRole: b"name",
            self.PathRole: b"path",
            self.IconRole: b"iconSource",
            self.RestoreRole: b"restorePath",
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self._items)

    @Property(int, notify=shortcutsChanged)
    def count(self) -> int:
        return len(self._items)

    @Property("QVariantList", notify=shortcutsChanged)
    def previewIcons(self) -> list[str]:
        return [item.icon_source for item in self._items[:4]]

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self._items):
            return None
        item = self._items[index.row()]
        if role == self.NameRole:
            return item.name
        if role == self.PathRole:
            return item.path
        if role == self.IconRole:
            return item.icon_source
        if role == self.RestoreRole:
            return item.restore_path
        return None

    @Slot("QVariantList")
    def addUrls(self, urls: list) -> None:
        for raw_url in urls:
            value = str(raw_url)
            path = QUrl(value).toLocalFile() if value.startswith("file:") else value
            self.addPath(path)

    @Slot(str)
    def addPath(self, raw_path: str) -> None:
        path = Path(raw_path)
        if not path.exists() or not path.is_file():
            return
        if path.suffix.lower() not in {".lnk", ".url", ".exe", ".bat", ".cmd"}:
            return
        normalized = os.path.normcase(os.path.abspath(str(path)))
        if any(
            os.path.normcase(item.path) == normalized
            or (item.restore_path and os.path.normcase(item.restore_path) == normalized)
            for item in self._items
        ):
            return
        launch_path = path
        restore_path = ""
        if self._is_desktop_shortcut(path):
            archived = self._archive_shortcut(path)
            if archived is not None:
                launch_path = archived
                restore_path = str(path)

        item = Shortcut(
            str(launch_path),
            path.stem,
            self._cache_icon(path),
            restore_path,
        )
        self.beginResetModel()
        self._items.append(item)
        self._items.sort(key=lambda entry: entry.name.casefold())
        self.endResetModel()
        self._save_items()
        self.shortcutsChanged.emit()

        # Remove only the dropped desktop shortcut. The original executable
        # and shortcuts dropped from other folders are never touched.
        if restore_path:
            try:
                path.unlink()
            except OSError:
                pass

    @Slot(str)
    def openPath(self, path: str) -> None:
        if not QDesktopServices.openUrl(QUrl.fromLocalFile(path)):
            try:
                os.startfile(path)  # type: ignore[attr-defined]
            except (AttributeError, OSError):
                subprocess.Popen([path], close_fds=True)

    @Slot(str)
    def removePath(self, path: str) -> None:
        for row, item in enumerate(self._items):
            if os.path.normcase(item.path) != os.path.normcase(path):
                continue
            self.beginRemoveRows(QModelIndex(), row, row)
            self._items.pop(row)
            self.endRemoveRows()
            if self._is_archive_path(Path(item.path)):
                try:
                    Path(item.path).unlink()
                except OSError:
                    pass
            self._save_items()
            self.shortcutsChanged.emit()
            return

    @Slot(str)
    def restorePath(self, path: str) -> None:
        for row, item in enumerate(self._items):
            if os.path.normcase(item.path) != os.path.normcase(path) or not item.restore_path:
                continue
            destination = Path(item.restore_path)
            if not destination.exists():
                try:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(item.path, destination)
                except OSError:
                    return
            self.beginRemoveRows(QModelIndex(), row, row)
            self._items.pop(row)
            self.endRemoveRows()
            try:
                Path(item.path).unlink()
            except OSError:
                pass
            self._save_items()
            self.shortcutsChanged.emit()
            return

    @staticmethod
    def _desktop_path() -> Path:
        desktop = QStandardPaths.writableLocation(QStandardPaths.DesktopLocation)
        return Path(desktop) if desktop else Path.home() / "Desktop"

    def _is_desktop_shortcut(self, path: Path) -> bool:
        return path.suffix.lower() == ".lnk" and os.path.normcase(
            os.path.abspath(path.parent)
        ) == os.path.normcase(os.path.abspath(self._desktop_path()))

    def _archive_shortcut(self, path: Path) -> Path | None:
        try:
            self._archive_dir.mkdir(parents=True, exist_ok=True)
            key = hashlib.sha1(os.path.normcase(str(path)).encode("utf-8")).hexdigest()
            target = self._archive_dir / f"{key}-{path.name}"
            shutil.copy2(path, target)
            return target
        except OSError:
            return None

    def _is_archive_path(self, path: Path) -> bool:
        try:
            return path.resolve().parent == self._archive_dir.resolve()
        except OSError:
            return False

    def _load_items(self) -> None:
        if not self._state_file.exists():
            return
        try:
            records = json.loads(self._state_file.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return
        for record in records:
            path = Path(str(record.get("path", "")))
            if not path.is_file():
                continue
            self._items.append(
                Shortcut(
                    str(path),
                    str(record.get("name") or path.stem),
                    self._cache_icon(path),
                    str(record.get("restore_path", "")),
                )
            )
        self._items.sort(key=lambda entry: entry.name.casefold())

    def _save_items(self) -> None:
        records = [
            {
                "path": item.path,
                "name": item.name,
                "restore_path": item.restore_path,
            }
            for item in self._items
        ]
        try:
            self._state_file.write_text(
                json.dumps(records, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        except OSError:
            pass

    def _cache_icon(self, path: Path) -> str:
        # QFileIconProvider includes Windows' shortcut overlay for .lnk files.
        # Read the target and use its icon so the shelf shows the app icon only.
        icon_path = self._shortcut_target(path) if path.suffix.lower() == ".lnk" else path
        icon = self._icon_provider.icon(QFileInfo(str(icon_path)))
        if icon.isNull():
            icon = QIcon()
        key = hashlib.sha1(
            f"{os.path.normcase(path)}|{os.path.normcase(icon_path)}|cropped-v2".encode("utf-8")
        ).hexdigest()
        target = self._icon_dir / f"{key}.png"
        if not target.exists():
            self._normalized_icon_pixmap(icon).save(str(target), "PNG")
        return QUrl.fromLocalFile(str(target)).toString()

    @staticmethod
    def _normalized_icon_pixmap(icon: QIcon) -> QPixmap:
        """Crop transparent shell padding while keeping a small visual margin."""

        source = icon.pixmap(256, 256)
        if source.isNull():
            return source

        visible_bounds = QRegion(source.mask()).boundingRect()
        if visible_bounds.isEmpty():
            return source

        cropped = source.copy(visible_bounds)
        canvas = QPixmap(256, 256)
        canvas.fill(Qt.transparent)

        # Leave roughly 8% padding so circular and rounded icons do not touch
        # the edge, while removing the much larger padding supplied by Shell.
        available = 232
        scaled = cropped.scaled(
            available,
            available,
            Qt.KeepAspectRatio,
            Qt.SmoothTransformation,
        )
        painter = QPainter(canvas)
        painter.drawPixmap(
            (canvas.width() - scaled.width()) // 2,
            (canvas.height() - scaled.height()) // 2,
            scaled,
        )
        painter.end()
        return canvas

    @staticmethod
    def _shortcut_target(path: Path) -> Path:
        """Resolve a Windows .lnk target without adding a COM dependency."""

        if os.name != "nt":
            return path
        try:
            command = (
                "$shortcut = New-Object -ComObject WScript.Shell; "
                "$shortcut.CreateShortcut($env:POGGET_LNK).TargetPath"
            )
            env = os.environ.copy()
            env["POGGET_LNK"] = str(path)
            result = subprocess.run(
                ["powershell", "-NoProfile", "-NonInteractive", "-Command", command],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=2,
                env=env,
                check=False,
            )
            target_text = (result.stdout or "").strip().lstrip("\ufeff")
            if not target_text:
                return path
            target = Path(target_text)
            return target if target.exists() else path
        except (OSError, subprocess.SubprocessError, ValueError):
            return path
