# SPDX-License-Identifier: GPL-2.0-or-later
"""Run with QT_QPA_PLATFORM=offscreen python3 tests/test_pinned_grid.py."""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
import unittest
import json
from PySide6.QtQml import QJSEngine
from pathlib import Path
from PySide6.QtCore import QAbstractListModel, QModelIndex, Qt, QUrl, QPoint, QPointF, QMetaObject, Q_ARG, Slot, QObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest

APP = QGuiApplication.instance() or QGuiApplication([])

class Favorites(QAbstractListModel):
    def __init__(self):
        super().__init__()
        self.launched = []
        self.ids = ['firefox.desktop', 'org.kde.dolphin.desktop', 'org.kde.konsole.desktop', 'org.kde.kate.desktop']
    def rowCount(self, parent=QModelIndex()):
        return len(self.ids) if not parent.isValid() else 0
    def roleNames(self):
        return {0: b'display', 1: b'decoration', 259: b'favoriteId'}
    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or index.row() >= len(self.ids): return None
        value = self.ids[index.row()]
        return value if role == 259 else value.replace('.desktop', '') if role == 0 else 'application-x-executable' if role == 1 else None
    @Slot(int, str, 'QVariant', result=bool)
    def trigger(self, row, action, argument):
        if 0 <= row < len(self.ids):
            self.launched.append(self.ids[row])
            return True
        return False
    # QML accesses the actual model count via a Qt property.
    from PySide6.QtCore import Property
    count = Property(int, lambda self: len(self.ids), constant=True)

class PinnedGridTest(unittest.TestCase):
    def setUp(self):
        self.model = Favorites()
        self.view = QQuickView()
        self.view.rootContext().setContextProperty('testFavorites', self.model)
        self.view.setSource(QUrl.fromLocalFile(str(Path(__file__).with_name('PinnedGridHarness.qml').resolve())))
        self.assertEqual(self.view.status(), QQuickView.Ready, self.view.errors())
        self.view.show()
        QTest.qWait(80)
        self.root = self.view.rootObject()
        self.grid = self.root.findChild(type(self.root), 'pinned')
        self.assertIsNotNone(self.grid)
    def tearDown(self):
        self.view.close()
        self.view.deleteLater()
        APP.processEvents()
    def value(self, name):
        value = self.grid.property(name)
        return value.toVariant() if hasattr(value, 'toVariant') else value
    def drag(self, start, end):
        QTest.mousePress(self.view, Qt.LeftButton, Qt.NoModifier, QPoint(*start))
        for step in range(1, 15):
            p = QPoint(round(start[0] + (end[0]-start[0])*step/14), round(start[1] + (end[1]-start[1])*step/14))
            QTest.mouseMove(self.view, p, 12)
        QTest.mouseRelease(self.view, Qt.LeftButton, Qt.NoModifier, QPoint(*end))
        QTest.qWait(50)
    def invoke(self, method, value):
        self.assertTrue(QMetaObject.invokeMethod(self.grid, method, Qt.DirectConnection, Q_ARG('QVariant', value)))
        QTest.qWait(20)
    def test_click_launches_pinned_app(self):
        QTest.mouseClick(self.view, Qt.LeftButton, Qt.NoModifier, QPoint(50, 30))
        QTest.qWait(20)
        self.assertEqual(self.model.launched, [self.model.ids[0]])

    def test_click_launches_app_inside_folder(self):
        self.drag((50, 30), (150, 30))
        app_id = self.value('cleanFolders')[0]['items'][0]
        pos = self.folder_app_position()
        QTest.mouseClick(self.view, Qt.LeftButton, Qt.NoModifier, QPoint(*pos))
        QTest.qWait(20)
        self.assertEqual(self.model.launched, [app_id])

    def test_sorting_and_launch_use_visible_app(self):
        self.grid.setProperty('sortMode', 1)
        QTest.qWait(20)
        entries = self.value('entries')
        self.assertEqual([e['favoriteId'] for e in entries], [self.model.ids[0], self.model.ids[1], self.model.ids[3], self.model.ids[2]])
        QTest.mouseClick(self.view, Qt.LeftButton, Qt.NoModifier, QPoint(250, 30))
        self.assertEqual(self.model.launched, [self.model.ids[3]])
        self.drag((50, 30), (150, 30))
        self.grid.setProperty('sortMode', 2)
        QTest.qWait(20)
        self.assertGreaterEqual(self.value('entries')[0]['folderIndex'], 0)
        self.grid.setProperty('sortMode', 3)
        QTest.qWait(20)
        entries = self.value('entries')
        self.assertGreaterEqual(entries[-1]['folderIndex'], 0)
        self.assertEqual([e['favoriteId'] for e in entries[:-1]], [self.model.ids[3], self.model.ids[2]])


    def test_drag_groups_adds_and_dissolves_without_unpinning(self):
        self.assertEqual(self.value('count'), 4)
        self.drag((50, 30), (150, 30))
        folders = self.value('cleanFolders')
        self.assertEqual(self.value('dragKey'), '')
        self.assertFalse(self.value('dragging'))
        self.assertEqual(len(folders), 1)
        self.assertEqual(folders[0]['items'], self.model.ids[:2][::-1])
        self.assertEqual(self.value('count'), 3)
        self.drag((150, 30), (50, 30))
        folders = self.value('cleanFolders')
        self.assertEqual(len(folders[0]['items']), 3)
        self.invoke('moveOut', self.model.ids[0])
        self.assertEqual(len(self.value('cleanFolders')[0]['items']), 2)
        self.invoke('dissolveFolder', folders[0]['id'])
        self.assertEqual(self.value('count'), 4)
        self.assertEqual(self.model.ids, ['firefox.desktop', 'org.kde.dolphin.desktop', 'org.kde.konsole.desktop', 'org.kde.kate.desktop'])
    def test_folder_survives_reload_and_keyboard_opens_it(self):
        self.drag((50, 30), (150, 30))
        folder = self.value('cleanFolders')[0]
        self.assertTrue(QMetaObject.invokeMethod(self.grid, 'renameFolder', Qt.DirectConnection,
                        Q_ARG('QVariant', folder['id']), Q_ARG('QVariant', 'Work')))
        QTest.qWait(20)
        self.assertEqual(self.value('cleanFolders')[0]['name'], 'Work')
        QMetaObject.invokeMethod(self.grid, 'rebuild', Qt.DirectConnection)
        self.assertEqual(self.value('cleanFolders')[0]['items'], folder['items'])
        self.grid.setProperty('currentIndex', 0)
        self.grid.forceActiveFocus()
        QTest.keyClick(self.view, Qt.Key_Return)
        QTest.qWait(20)
        self.assertTrue(self.grid.property('folderOpen'))
        QTest.keyClick(self.view, Qt.Key_Escape)
        self.grid.forceActiveFocus()
        QTest.keyClick(self.view, Qt.Key_Right)
        self.assertEqual(self.value('currentIndex'), 1)

    def test_folder_title_and_separate_rename_save_cancel(self):
        self.drag((50, 30), (150, 30))
        self.folder_app_position()
        title = self.root.findChild(QObject, 'folderTitle')
        original = title.property('text')
        button = self.root.findChild(type(self.root), 'renameFolderButton')
        point = button.mapToScene(QPointF(button.width() / 2, button.height() / 2))
        QTest.mouseClick(self.view, Qt.LeftButton, Qt.NoModifier, point.toPoint())
        QTest.qWait(20)
        dialog = self.root.findChild(QObject, 'renameFolderDialog')
        field = self.root.findChild(QObject, 'folderNameInput')
        self.assertTrue(dialog.property('visible'))
        field.setProperty('text', 'Cancelled name')
        QMetaObject.invokeMethod(dialog, 'reject')
        QTest.qWait(20)
        self.assertEqual(title.property('text'), original)
        QTest.mouseClick(self.view, Qt.LeftButton, Qt.NoModifier, point.toPoint())
        QTest.qWait(20)
        field.setProperty('text', 'My apps')
        QMetaObject.invokeMethod(dialog, 'accept')
        QTest.qWait(20)
        self.assertEqual(title.property('text'), 'My apps')

    def folder_app_position(self):
        folder = self.value('cleanFolders')[0]
        self.invoke('openFolder', folder['id'])
        apps = self.root.findChild(type(self.root), 'folderApps')
        p = apps.mapToScene(QPointF(60, 30))
        return (round(p.x()), round(p.y()))

    def test_drag_out_to_empty_grid_space(self):
        self.drag((50, 30), (150, 30))
        source_id = self.value('cleanFolders')[0]['items'][0]
        self.drag(self.folder_app_position(), (550, 320))
        self.assertNotIn(source_id, self.value('cleanFolders')[0]['items'])
        self.assertIn(source_id, [e['favoriteId'] for e in self.value('entries')])
        self.assertEqual(self.value('count'), 4)
        self.assertFalse(self.grid.property('folderOpen'))

    def test_drag_out_to_tile_edge(self):
        self.drag((50, 30), (150, 30))
        source_id = self.value('cleanFolders')[0]['items'][0]
        self.drag(self.folder_app_position(), (298, 30))
        self.assertNotIn(source_id, self.value('cleanFolders')[0]['items'])
        self.assertEqual(self.value('entries')[-1]['favoriteId'], source_id)

    def test_drop_inside_folder_keeps_membership(self):
        self.drag((50, 30), (150, 30))
        before = self.value('cleanFolders')
        start = self.folder_app_position()
        self.drag(start, (start[0] + 30, start[1]))
        self.assertEqual(self.value('cleanFolders'), before)

    def test_edge_drop_reorders_and_cancel_does_not_group(self):
        self.drag((50, 30), (298, 30))
        self.assertEqual(self.value('cleanFolders'), [])
        self.assertEqual([e['favoriteId'] for e in self.value('entries')], self.model.ids[1:3] + self.model.ids[:1] + self.model.ids[3:])
        before = self.value('entries')
        self.drag((50, 30), (590, 340))
        self.assertEqual(self.value('entries'), before)

class LayoutDataTest(unittest.TestCase):
    def test_migration_prunes_missing_and_duplicate_apps(self):
        engine = QJSEngine()
        path = Path(__file__).parents[1] / 'contents/ui/code/PinnedLayout.js'
        engine.evaluate(path.read_text())
        result = engine.evaluate('JSON.stringify(normalize([{name:"Old",items:["a","a","missing"]},{name:"Other",items:["a","b"]}], ["a","b"]))')
        folders = json.loads(result.toString())
        self.assertEqual([f['items'] for f in folders], [['a'], ['b']])
        self.assertEqual(len(set(f['id'] for f in folders)), 2)
    def test_self_drop_is_noop_and_stale_order_is_ignored(self):
        engine = QJSEngine()
        engine.evaluate((Path(__file__).parents[1] / 'contents/ui/code/PinnedLayout.js').read_text())
        self.assertTrue(engine.evaluate('group([], ["app:a"], "a", "app:a", "new", "Folder") === null').toBool())
        result = engine.evaluate('JSON.stringify(project(["a","b"], [], ["app:missing","app:b","app:b"]))')
        self.assertEqual([e['favoriteId'] for e in json.loads(result.toString())], ['b', 'a'])

if __name__ == '__main__': unittest.main()
