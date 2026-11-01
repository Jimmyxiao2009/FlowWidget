from __future__ import annotations

import json
import os
import shutil
import uuid
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import (
    QAbstractListModel,
    QModelIndex,
    QObject,
    Property,
    QStandardPaths,
    Qt,
    Signal,
    Slot,
)

from .folder_shelf_model import FolderShelfModel
from .shortcut_model import ShortcutModel


class ShelfCollectionModel(QAbstractListModel):
    IdRole = Qt.UserRole + 1
    NameRole = Qt.UserRole + 2
    CategoryRole = Qt.UserRole + 3
    CountRole = Qt.UserRole + 4
    UpdatedRole = Qt.UserRole + 5
    PreviewIconsRole = Qt.UserRole + 6

    boxesChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        base = Path(
            os.environ.get(
                "LOCALAPPDATA",
                QStandardPaths.writableLocation(QStandardPaths.AppLocalDataLocation),
            )
        ) / "FlowWidget"
        self._data_dir = base / "shelves"
        self._data_dir.mkdir(parents=True, exist_ok=True)
        self._state_file = self._data_dir / "boxes.json"
        self._boxes: list[dict[str, str]] = []
        self._models: dict[str, ShortcutModel | FolderShelfModel] = {}
        self._load()
        if not self._boxes:
            self._boxes.append(self._new_record("我的收纳箱", "软件收纳箱"))
            self._save()
        self._migrate_legacy_shortcuts(base / "shortcuts.json")

    def roleNames(self):
        return {
            self.IdRole: b"boxId",
            self.NameRole: b"name",
            self.CategoryRole: b"category",
            self.CountRole: b"itemCount",
            self.UpdatedRole: b"updatedText",
            self.PreviewIconsRole: b"previewIcons",
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self._boxes)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self._boxes):
            return None
        record = self._boxes[index.row()]
        model = self.model_for_box(record["id"])
        values = {
            self.IdRole: record["id"],
            self.NameRole: record["name"],
            self.CategoryRole: record["category"],
            self.CountRole: model.count,
            self.UpdatedRole: record["updated"],
            self.PreviewIconsRole: model.previewIcons,
        }
        return values.get(role)

    @Property(int, notify=boxesChanged)
    def count(self) -> int:
        return len(self._boxes)

    @Property(int, notify=boxesChanged)
    def totalItemCount(self) -> int:
        return sum(self.model_for_box(box["id"]).count for box in self._boxes)

    @Property(str, notify=boxesChanged)
    def defaultBoxId(self) -> str:
        return self._boxes[0]["id"] if self._boxes else ""

    @Slot(str, str, result=str)
    def createBox(self, name: str, category: str) -> str:
        clean_name = name.strip()
        if not clean_name:
            return ""
        record = self._new_record(clean_name, self._normalize_category(category))
        row = len(self._boxes)
        self.beginInsertRows(QModelIndex(), row, row)
        self._boxes.append(record)
        self.endInsertRows()
        self._save()
        self.boxesChanged.emit()
        return record["id"]

    @Slot(str, str, str)
    def updateBox(self, box_id: str, name: str, category: str) -> None:
        row = self._row_for_id(box_id)
        clean_name = name.strip()
        if row < 0 or not clean_name:
            return
        normalized_category = self._normalize_category(category)
        if self._boxes[row]["category"] != normalized_category:
            self._models.pop(box_id, None)
        self._boxes[row]["name"] = clean_name
        self._boxes[row]["category"] = normalized_category
        self._touch(row)

    @Slot(str, result=bool)
    def deleteBox(self, box_id: str) -> bool:
        row = self._row_for_id(box_id)
        if row < 0:
            return False
        model = self.model_for_box(box_id)
        if isinstance(model, FolderShelfModel) and not model.prepare_for_box_deletion():
            return False
        self.beginRemoveRows(QModelIndex(), row, row)
        record = self._boxes.pop(row)
        self.endRemoveRows()
        self._models.pop(box_id, None)
        box_dir = self._data_dir / record["id"]
        if box_dir.is_dir():
            shutil.rmtree(box_dir, ignore_errors=True)
        if not self._boxes:
            self.beginInsertRows(QModelIndex(), 0, 0)
            self._boxes.append(self._new_record("我的收纳箱", "软件收纳箱"))
            self.endInsertRows()
        self._save()
        self.boxesChanged.emit()
        return True

    @Slot(str, result="QVariantMap")
    def boxInfo(self, box_id: str) -> dict:
        row = self._row_for_id(box_id)
        if row < 0:
            return {}
        return dict(self._boxes[row])

    @Slot(str, result="QVariantList")
    def searchBoxes(self, query: str) -> list[dict]:
        needle = query.strip().casefold()
        result = []
        for record in self._boxes:
            if needle and needle not in record["name"].casefold() and needle not in record["category"].casefold():
                continue
            model = self.model_for_box(record["id"])
            result.append({
                "boxId": record["id"],
                "name": record["name"],
                "category": record["category"],
                "itemCount": model.count,
                "updatedText": record["updated"],
                "previewIcons": model.previewIcons,
            })
        return result

    def model_for_box(self, box_id: str) -> ShortcutModel | FolderShelfModel:
        if box_id not in self._models:
            box_dir = self._data_dir / box_id
            if self.category_for_box(box_id) == "文件夹收纳箱":
                model = FolderShelfModel(
                    self,
                    state_file=box_dir / "folders.json",
                    managed_dir=box_dir / "managed-items",
                )
                model.itemsChanged.connect(lambda bid=box_id: self._on_items_changed(bid))
            else:
                model = ShortcutModel(
                    self,
                    state_file=box_dir / "shortcuts.json",
                    archive_dir=box_dir / "files",
                )
                model.shortcutsChanged.connect(lambda bid=box_id: self._on_items_changed(bid))
            self._models[box_id] = model
        return self._models[box_id]

    def name_for_box(self, box_id: str) -> str:
        row = self._row_for_id(box_id)
        return self._boxes[row]["name"] if row >= 0 else "收纳箱"

    def category_for_box(self, box_id: str) -> str:
        row = self._row_for_id(box_id)
        return self._boxes[row]["category"] if row >= 0 else "软件收纳箱"

    def rename_box(self, box_id: str, name: str) -> None:
        row = self._row_for_id(box_id)
        if row >= 0:
            self.updateBox(box_id, name, self._boxes[row]["category"])

    def _on_items_changed(self, box_id: str) -> None:
        row = self._row_for_id(box_id)
        if row < 0:
            return
        self._boxes[row]["updated"] = datetime.now().strftime("%Y-%m-%d")
        self._save()
        index = self.index(row, 0)
        self.dataChanged.emit(index, index, [self.CountRole, self.UpdatedRole, self.PreviewIconsRole])
        self.boxesChanged.emit()

    def _touch(self, row: int) -> None:
        self._boxes[row]["updated"] = datetime.now().strftime("%Y-%m-%d")
        self._save()
        index = self.index(row, 0)
        self.dataChanged.emit(index, index)
        self.boxesChanged.emit()

    def _row_for_id(self, box_id: str) -> int:
        return next((i for i, box in enumerate(self._boxes) if box["id"] == box_id), -1)

    @staticmethod
    def _normalize_category(category: str) -> str:
        return category if category in {"软件收纳箱", "文件收纳箱", "文件夹收纳箱"} else "软件收纳箱"

    @staticmethod
    def _new_record(name: str, category: str) -> dict[str, str]:
        return {
            "id": uuid.uuid4().hex,
            "name": name,
            "category": category,
            "updated": datetime.now().strftime("%Y-%m-%d"),
        }

    def _load(self) -> None:
        if not self._state_file.exists():
            return
        try:
            records = json.loads(self._state_file.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return
        if isinstance(records, list):
            self._boxes = [record for record in records if isinstance(record, dict) and record.get("id") and record.get("name")]

    def _save(self) -> None:
        try:
            self._state_file.write_text(json.dumps(self._boxes, ensure_ascii=False, indent=2), encoding="utf-8")
        except OSError:
            pass

    def _migrate_legacy_shortcuts(self, legacy_file: Path) -> None:
        if not legacy_file.is_file() or not self._boxes:
            return
        target = self._data_dir / self._boxes[0]["id"] / "shortcuts.json"
        if target.exists():
            return
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            shutil.copy2(legacy_file, target)
        except OSError:
            return
        self._models.pop(self._boxes[0]["id"], None)
