from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import uuid
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
from PySide6.QtGui import QDesktopServices, QPainter, QPixmap, QRegion
from PySide6.QtWidgets import QFileIconProvider


ARCHIVE_SUFFIXES = {
    ".zip",
    ".rar",
    ".7z",
    ".tar",
    ".gz",
    ".bz2",
    ".xz",
    ".tgz",
    ".tbz",
    ".tbz2",
    ".txz",
    ".cab",
}


@dataclass(frozen=True)
class FolderEntry:
    path: str
    name: str
    icon_source: str
    restore_path: str = ""
    is_directory: bool = False
    is_archive: bool = False


class FolderShelfModel(QAbstractListModel):
    """Stores folder shelf roots and exposes an Explorer-like child view."""

    NameRole = Qt.UserRole + 1
    PathRole = Qt.UserRole + 2
    IconRole = Qt.UserRole + 3
    RestoreRole = Qt.UserRole + 4
    DirectoryRole = Qt.UserRole + 5
    ArchiveRole = Qt.UserRole + 6

    itemsChanged = Signal()
    viewChanged = Signal()
    lastErrorChanged = Signal()

    def __init__(
        self,
        parent: QObject | None = None,
        state_file: Path | None = None,
        managed_dir: Path | None = None,
        desktop_dir: Path | None = None,
    ) -> None:
        super().__init__(parent)
        base = Path(
            os.environ.get(
                "LOCALAPPDATA",
                QStandardPaths.writableLocation(QStandardPaths.AppLocalDataLocation),
            )
        ) / "FlowWidget"
        self._state_file = state_file or (base / "folder-shelf.json")
        self._managed_dir = managed_dir or (base / "folder-shelf-items")
        desktop = QStandardPaths.writableLocation(QStandardPaths.DesktopLocation)
        self._desktop_dir = desktop_dir or (Path(desktop) if desktop else Path.home() / "Desktop")
        self._state_file.parent.mkdir(parents=True, exist_ok=True)
        self._managed_dir.mkdir(parents=True, exist_ok=True)

        self._icon_provider = QFileIconProvider()
        self._icon_dir = Path(tempfile.gettempdir()) / "flowwidget-folder-icons"
        self._icon_dir.mkdir(parents=True, exist_ok=True)
        self._items: list[FolderEntry] = []
        self._browser_entries: list[FolderEntry] = []
        self._browse_root: Path | None = None
        self._current_path: Path | None = None
        self._last_error = ""
        self._load_items()

    def roleNames(self):
        return {
            self.NameRole: b"name",
            self.PathRole: b"path",
            self.IconRole: b"iconSource",
            self.RestoreRole: b"restorePath",
            self.DirectoryRole: b"isDirectory",
            self.ArchiveRole: b"isArchive",
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:
        if parent.isValid():
            return 0
        return len(self._browser_entries if self._current_path else self._items)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        entries = self._browser_entries if self._current_path else self._items
        if not index.isValid() or not 0 <= index.row() < len(entries):
            return None
        item = entries[index.row()]
        values = {
            self.NameRole: item.name,
            self.PathRole: item.path,
            self.IconRole: item.icon_source,
            self.RestoreRole: item.restore_path,
            self.DirectoryRole: item.is_directory,
            self.ArchiveRole: item.is_archive,
        }
        return values.get(role)

    @Property(int, notify=itemsChanged)
    def count(self) -> int:
        return len(self._items)

    @Property("QVariantList", notify=itemsChanged)
    def previewIcons(self) -> list[str]:
        return [item.icon_source for item in self._items[:4]]

    @Property(bool, notify=viewChanged)
    def browsing(self) -> bool:
        return self._current_path is not None

    @Property(str, notify=viewChanged)
    def currentPath(self) -> str:
        return str(self._current_path) if self._current_path else ""

    @Property(str, notify=lastErrorChanged)
    def lastError(self) -> str:
        return self._last_error

    @Slot()
    def clearError(self) -> None:
        self._set_error("")

    @Slot("QVariantList")
    def addUrls(self, urls: list) -> None:
        accepted = 0
        rejected = 0
        for raw_url in urls:
            value = str(raw_url)
            path = QUrl(value).toLocalFile() if value.startswith("file:") else value
            if self._add_path(Path(path)):
                accepted += 1
            else:
                rejected += 1
        if accepted and not rejected:
            self._set_error("")
        elif rejected:
            self._set_error("文件夹收纳箱只支持文件夹和常见压缩包")

    @Slot(str)
    def addPath(self, raw_path: str) -> None:
        if not self._add_path(Path(raw_path)):
            self._set_error("文件夹收纳箱只支持文件夹和常见压缩包")

    def _add_path(self, path: Path) -> bool:
        if not path.exists() or not (path.is_dir() or self._is_archive(path)):
            return False

        normalized = self._normalized(path)
        if any(
            self._normalized(Path(item.path)) == normalized
            or (item.restore_path and self._normalized(Path(item.restore_path)) == normalized)
            for item in self._items
        ):
            self._set_error("这个项目已经在收纳箱中了")
            return False

        original_path = path
        stored_path = path
        restore_path = ""
        if self._is_desktop_item(path):
            target = self._managed_target(path.name)
            try:
                shutil.move(str(path), str(target))
            except OSError:
                self._set_error("无法从桌面移动这个项目，请检查它是否正在使用")
                return False
            stored_path = target
            restore_path = str(original_path)

        item = self._entry_for_path(stored_path, restore_path, original_path.name)
        self.beginResetModel()
        self._items.append(item)
        self._items.sort(key=lambda entry: (not entry.is_directory, entry.name.casefold()))
        self.endResetModel()
        self._save_items()
        self.itemsChanged.emit()
        return True

    @Slot(str, bool)
    def activatePath(self, raw_path: str, is_directory: bool) -> None:
        if is_directory:
            self.enterFolder(raw_path)
        else:
            self.openPath(raw_path)

    @Slot(str)
    def enterFolder(self, raw_path: str) -> None:
        path = Path(raw_path)
        if not path.is_dir():
            self._set_error("文件夹不存在或已被移动")
            return

        resolved = self._resolved(path)
        if self._browse_root is None or self._current_path is None:
            self._browse_root = resolved
        elif not self._is_within(resolved, self._browse_root):
            self._set_error("不能从当前收纳目录跳转到外部路径")
            return

        self._current_path = resolved
        self._reload_browser_entries()

    @Slot()
    def goBack(self) -> None:
        if self._current_path is None or self._browse_root is None:
            return
        if self._normalized(self._current_path) == self._normalized(self._browse_root):
            self.showOverview()
            return
        parent = self._current_path.parent
        if not self._is_within(parent, self._browse_root):
            self.showOverview()
            return
        self._current_path = parent
        self._reload_browser_entries()

    @Slot()
    def showOverview(self) -> None:
        if self._current_path is None:
            return
        self.beginResetModel()
        self._current_path = None
        self._browse_root = None
        self._browser_entries = []
        self.endResetModel()
        self.viewChanged.emit()

    @Slot(str)
    def openPath(self, raw_path: str) -> None:
        path = Path(raw_path)
        if not path.exists():
            self._set_error("项目不存在或已被移动")
            return
        if os.name == "nt":
            try:
                os.startfile(str(path))  # type: ignore[attr-defined]
                return
            except (AttributeError, OSError):
                self._set_error("Windows 找不到可以打开这个文件的程序")
                return
        if not QDesktopServices.openUrl(QUrl.fromLocalFile(str(path))):
            self._set_error("系统找不到可以打开这个文件的程序")

    @Slot()
    def openInExplorer(self) -> None:
        if self._current_path is not None:
            self._open_explorer(self._current_path)

    @Slot(str)
    def showInExplorer(self, raw_path: str) -> None:
        path = Path(raw_path)
        if path.exists():
            self._open_explorer(path)

    @Slot(str)
    def removePath(self, raw_path: str) -> None:
        row = self._root_row(raw_path)
        if row < 0:
            return
        item = self._items[row]
        path = Path(item.path)
        if self._is_managed_path(path):
            try:
                if path.is_dir():
                    shutil.rmtree(path)
                elif path.exists():
                    path.unlink()
            except OSError:
                self._set_error("删除失败，请检查项目是否正在使用")
                return
        self.beginRemoveRows(QModelIndex(), row, row)
        self._items.pop(row)
        self.endRemoveRows()
        self._save_items()
        self.itemsChanged.emit()

    @Slot(str)
    def restorePath(self, raw_path: str) -> None:
        row = self._root_row(raw_path)
        if row < 0:
            return
        item = self._items[row]
        if not item.restore_path:
            return
        source = Path(item.path)
        destination = Path(item.restore_path)
        if destination.exists():
            self._set_error("原位置已有同名项目，未执行覆盖")
            return
        try:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(source), str(destination))
        except OSError:
            self._set_error("恢复失败，请检查项目是否正在使用")
            return
        self.beginRemoveRows(QModelIndex(), row, row)
        self._items.pop(row)
        self.endRemoveRows()
        self._save_items()
        self.itemsChanged.emit()

    def prepare_for_box_deletion(self) -> bool:
        """Move every managed desktop item back out before its box is removed."""

        recovery_dir = self._desktop_dir / "FlowWidget恢复"
        for item in list(self._items):
            source = Path(item.path)
            if not item.restore_path or not self._is_managed_path(source) or not source.exists():
                continue
            destination = Path(item.restore_path)
            if destination.exists():
                recovery_dir.mkdir(parents=True, exist_ok=True)
                destination = self._unique_destination(recovery_dir / Path(item.restore_path).name)
            try:
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(source), str(destination))
            except OSError:
                self._set_error("收纳箱中仍有无法恢复的项目，因此没有删除收纳箱")
                return False
        return True

    def _reload_browser_entries(self) -> None:
        assert self._current_path is not None
        entries: list[FolderEntry] = []
        try:
            children = list(self._current_path.iterdir())
        except OSError:
            self._set_error("无法读取这个文件夹")
            self.showOverview()
            return
        for child in children:
            try:
                is_directory = child.is_dir()
                is_archive = child.is_file() and self._is_archive(child)
            except OSError:
                continue
            entries.append(
                FolderEntry(
                    path=str(child),
                    name=child.name,
                    icon_source=self._cache_icon(child),
                    is_directory=is_directory,
                    is_archive=is_archive,
                )
            )
        entries.sort(key=lambda entry: (not entry.is_directory, entry.name.casefold()))
        self.beginResetModel()
        self._browser_entries = entries
        self.endResetModel()
        self.viewChanged.emit()

    def _entry_for_path(self, path: Path, restore_path: str, display_name: str) -> FolderEntry:
        return FolderEntry(
            path=str(path),
            name=display_name,
            icon_source=self._cache_icon(path),
            restore_path=restore_path,
            is_directory=path.is_dir(),
            is_archive=self._is_archive(path),
        )

    def _root_row(self, raw_path: str) -> int:
        normalized = self._normalized(Path(raw_path))
        return next(
            (index for index, item in enumerate(self._items) if self._normalized(Path(item.path)) == normalized),
            -1,
        )

    def _managed_target(self, name: str) -> Path:
        return self._managed_dir / f"{uuid.uuid4().hex[:10]}-{name}"

    @staticmethod
    def _unique_destination(path: Path) -> Path:
        if not path.exists():
            return path
        stem = path.stem
        suffix = path.suffix
        for number in range(2, 10000):
            candidate = path.with_name(f"{stem} ({number}){suffix}")
            if not candidate.exists():
                return candidate
        return path.with_name(f"{stem}-{uuid.uuid4().hex[:8]}{suffix}")

    def _is_desktop_item(self, path: Path) -> bool:
        return self._normalized(path.parent) == self._normalized(self._desktop_dir)

    def _is_managed_path(self, path: Path) -> bool:
        return self._is_within(self._resolved(path), self._resolved(self._managed_dir))

    @staticmethod
    def _is_archive(path: Path) -> bool:
        return path.is_file() and path.suffix.casefold() in ARCHIVE_SUFFIXES

    @staticmethod
    def _normalized(path: Path) -> str:
        return os.path.normcase(os.path.abspath(str(path)))

    @staticmethod
    def _resolved(path: Path) -> Path:
        try:
            return path.resolve()
        except OSError:
            return Path(os.path.abspath(str(path)))

    def _is_within(self, path: Path, parent: Path) -> bool:
        try:
            path.relative_to(parent)
            return True
        except ValueError:
            return False

    def _load_items(self) -> None:
        if not self._state_file.is_file():
            return
        try:
            records = json.loads(self._state_file.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return
        if not isinstance(records, list):
            return
        for record in records:
            if not isinstance(record, dict):
                continue
            path = Path(str(record.get("path", "")))
            if not path.exists() or not (path.is_dir() or self._is_archive(path)):
                continue
            self._items.append(
                self._entry_for_path(
                    path,
                    str(record.get("restore_path", "")),
                    str(record.get("name") or path.name),
                )
            )
        self._items.sort(key=lambda entry: (not entry.is_directory, entry.name.casefold()))

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
            self._set_error("无法保存收纳箱记录")

    def _cache_icon(self, path: Path) -> str:
        try:
            modified = path.stat().st_mtime_ns
        except OSError:
            modified = 0
        key = hashlib.sha1(
            f"{self._normalized(path)}|{modified}|cropped-v2".encode("utf-8")
        ).hexdigest()
        target = self._icon_dir / f"{key}.png"
        if not target.exists():
            icon = self._icon_provider.icon(QFileInfo(str(path)))
            pixmap = self._normalized_icon_pixmap(icon.pixmap(256, 256))
            if not pixmap.isNull():
                pixmap.save(str(target), "PNG")
        return QUrl.fromLocalFile(str(target)).toString()

    @staticmethod
    def _normalized_icon_pixmap(source: QPixmap) -> QPixmap:
        """Remove transparent Shell padding so the visible glyph fills its cell."""

        if source.isNull():
            return source
        visible_bounds = QRegion(source.mask()).boundingRect()
        if visible_bounds.isEmpty():
            return source

        cropped = source.copy(visible_bounds)
        canvas = QPixmap(256, 256)
        canvas.fill(Qt.transparent)
        scaled = cropped.scaled(
            232,
            232,
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
    def _open_explorer(path: Path) -> None:
        if os.name == "nt":
            if path.is_dir():
                subprocess.Popen(["explorer.exe", str(path)], close_fds=True)
            else:
                subprocess.Popen(["explorer.exe", f"/select,{path}"], close_fds=True)
        else:
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(path if path.is_dir() else path.parent)))

    def _set_error(self, message: str) -> None:
        if message == self._last_error:
            return
        self._last_error = message
        self.lastErrorChanged.emit()
