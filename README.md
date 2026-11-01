# Menu 11 Next Level

A personal fork of Menu 11 Next with folders inside the pinned application grid.
It installs as **Menu 11 Next Level** alongside existing launchers.

## Pinned folders

- Drag an app onto the **centre** of another pinned app, then release to create a folder.
- Drop an app on a folder to add it. A highlight ring shows the grouping target.
- Drop near the **left or right edge** of a tile to reorder. A line shows the insertion point.
- Click a folder to open it. Use the rename button beside its larger title to edit the name, then Save or Cancel.
- Drag an app out of an open folder onto empty pinned-grid space or a tile edge to move it out.
- You can also right-click an app inside a folder and choose **Move out of folder**.
- Right-click a folder and choose **Dissolve folder** to return its apps to the grid.
- The folder button creates an empty folder that you can name and fill by dragging apps.

Folders and tile order are saved per widget. Grouping does not remove applications
from KDE's underlying favorites. Existing folder data is migrated on use.
Keyboard navigation, pagination, and Ctrl+1–9 follow the visible grid, including folders.

## Personalisation and system information

In **Configure → General**:

- Sort favourites manually, A–Z, folders first, or folders last (A–Z within each type).
  Dropping between tiles switches back to manual order.
- Set the circular profile picture size from 24 to 96 pixels.
- Show or hide the local IP address, home-filesystem disk space, and RAM usage separately.
  Readings refresh every five seconds while the menu is open; no network requests are made.

Click the profile area to open **System Settings → Users**. The greeting and recent
documents section have been removed. Normal clicks launch apps both in the pinned
grid and inside folders, including when the grid is sorted.

## Install

```sh
kpackagetool6 --type Plasma/Applet --install .
```

Then add **Menu 11 Next Level** from Plasma's widget list. To switch your panel launcher,
right-click its icon and select **Show Alternatives**.

## Validation

The interaction tests use PySide6 and the system KDE QML modules:

```sh
QT_QPA_PLATFORM=offscreen python3 tests/test_pinned_grid.py
```

They exercise mouse drags, grouping, adding to folders, edge reordering, cancelled
drags, moving out, dissolving, keyboard opening, renaming and legacy-data validation.

---

## Upstream documentation

### Menu 11 Next

## Windows 11 menu launcher for KDE Plasma 6.5
Based on [menu 11 plasma6,](https://github.com/adhec/OnzeMenuKDE), with some tweaks & modifications to make it fully working with the most recent kde plasma.
Small design tweaks (moure rounded search bar, no blue underline, light gray background hover app select / buttons)


## Features
- Search bar: auto-selects first result, supports `/` command mode, `/calc` math evaluation
- Customizable layout: List, Grid, and Category view modes
- Extensive sorting: A-Z, Z-A, Newest, Oldest, and Type
- Organize apps: Folder support for All Apps page with drag-and-drop
- Shortcuts:
  - Ctrl + 1-9 to launch pinned apps
  - Alt + 1-9 to launch search results
  - Home / End navigation for grids
  - Tab cycle for keyboard navigation
- Workflow-aware: Adaptive suggestions based on time and frequency
- Contextual Actions: Quick launch bar with common system utilities
- Pinned/Favorite applications
- Recent documents & files support
- Shutdown / Restart / Sleep / Lock / Logout options

## Fixed
- Alphabetical slider navigation in All Apps
- Search result overlap and scrolling issues
- Correct height calculation for multi-column grids
- Focus ring and tab-cycle navigation
- Plugin-based search provider stability
- Folder management UI and drag-and-drop interactions
- Corrected role mapping for Qt6 compatibility

## Installation

### Requirements
- KDE Plasma 6.5+
- `cmake`, `extra-cmake-modules`, `kpackagetool6`

### Method 1: Install via KDE Store (Recommended)
Search for **Menu 11 Next** in *System Settings → Get New Widgets*.

## Method 2: install via source
0. Download Github project - Code - download zip
1. Right click Select Add Widgets... from desktop menu.
2. Select Get New Widgets -> Install widget from local file
3. Search for the downloaded zip

OR from CLI

```bash
# Clone the repository
git clone https://github.com/Eisteed/menu-11-next.git
cd menu-11-next

# Install the widget
kpackagetool6 --install . --type Plasma/Applet
```

### Method 3: Install via plasmapkg2 (older systems)
```bash
plasmapkg2 --install . --type Plasma/Applet
```

### After Installing
1. Right-click your taskbar → *Add Widgets*
2. Search for **Menu 11 Next**
3. Drag it onto your panel

### Uninstall

```bash
kpackagetool6 --type Plasma/Applet --remove menu.11.next
```

---

## Screenshot
![Screenshot 1](https://github.com/user-attachments/assets/d23167b0-cc04-4cad-bf1d-3a11bca9a0c7)
![Screenshot 2](https://github.com/user-attachments/assets/5d9d59bd-969a-4671-beb2-72a4c40870e0)
![Screenshot 2](https://github.com/user-attachments/assets/77176635-8cac-42a6-b913-f40e715b48be)
