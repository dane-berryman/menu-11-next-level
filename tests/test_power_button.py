# SPDX-License-Identifier: GPL-2.0-or-later
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
import unittest
from pathlib import Path
from PySide6.QtCore import QObject, Property, Signal, Slot, QUrl, QPoint, QPointF, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView, QQuickItem
from PySide6.QtTest import QTest

APP = QGuiApplication.instance() or QGuiApplication([])

class Session(QObject):
    changed = Signal()
    canShutdown = Property(bool, lambda self: True, constant=True)
    canReboot = Property(bool, lambda self: True, constant=True)
    canLogout = Property(bool, lambda self: True, constant=True)
    canSuspend = Property(bool, lambda self: self.suspendAllowed, notify=changed)
    def __init__(self):
        super().__init__()
        self.calls = []
        self.suspendAllowed = True
    @Slot()
    def requestShutdown(self): self.calls.append('shutdown')
    @Slot()
    def requestReboot(self): self.calls.append('restart')
    @Slot()
    def suspend(self): self.calls.append('suspend')
    @Slot()
    def requestLogout(self): self.calls.append('logout')

class PowerButtonTest(unittest.TestCase):
    def setUp(self):
        self.session = Session()
        self.view = QQuickView()
        self.view.rootContext().setContextProperty('testSession', self.session)
        self.view.setSource(QUrl.fromLocalFile(str(Path(__file__).with_name('PowerButtonHarness.qml').resolve())))
        self.assertEqual(self.view.status(), QQuickView.Ready, self.view.errors())
        self.view.show()
        QTest.qWait(50)
    def tearDown(self):
        self.view.close()
        self.view.deleteLater()
        APP.processEvents()
    def click(self, name):
        item = self.view.rootObject().findChild(QQuickItem, name)
        self.assertIsNotNone(item)
        point = item.mapToScene(QPointF(item.width()/2, item.height()/2)).toPoint()
        QTest.mouseClick(self.view, Qt.LeftButton, Qt.NoModifier, point)
        QTest.qWait(50)
    def test_one_button_opens_menu_without_action(self):
        self.assertEqual(len(self.view.rootObject().findChildren(QQuickItem,'powerButton')),1)
        self.click('powerButton')
        menu = self.view.rootObject().findChild(QObject,'powerMenu')
        self.assertTrue(menu.property('opened'))
        self.assertEqual(self.session.calls, [])
    def test_each_option_routes_to_session_manager(self):
        for action, expected in [('powerOffAction','shutdown'),('restartAction','restart'),('suspendAction','suspend'),('logoutAction','logout')]:
            self.click('powerButton')
            self.click(action)
            self.assertEqual(self.session.calls[-1], expected)
        self.assertEqual(len(self.session.calls),4)
    def test_unavailable_suspend_is_disabled(self):
        self.session.suspendAllowed = False
        self.session.changed.emit()
        self.click('powerButton')
        action = self.view.rootObject().findChild(QQuickItem,'suspendAction')
        self.assertFalse(action.isEnabled())
        self.click('suspendAction')
        self.assertEqual(self.session.calls, [])

if __name__ == '__main__': unittest.main()
