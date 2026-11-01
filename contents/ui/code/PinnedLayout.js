// SPDX-License-Identifier: GPL-2.0-or-later
// Keep KDE's favorites intact. Folders only change their presentation in this widget.
function normalize(folders, favorites) {
    var used = {};
    return (Array.isArray(folders) ? folders : []).filter(function(f) {
        return f && typeof f.name === "string" && Array.isArray(f.items);
    }).map(function(f, index) {
        var items = f.items.filter(function(id) {
            if (favorites.indexOf(id) < 0 || used[id]) return false;
            used[id] = true;
            return true;
        });
        return { id: f.id || "legacy-" + index, name: f.name, items: items };
    });
}

function project(favorites, folders, order) {
    var grouped = {}, keys = [], entries = {};
    folders.forEach(function(f, index) {
        var key = "folder:" + f.id;
        keys.push(key);
        entries[key] = { key: key, folderIndex: index, favoriteId: "", name: f.name };
        f.items.forEach(function(id) { grouped[id] = true; });
    });
    favorites.forEach(function(id) {
        if (grouped[id]) return;
        var key = "app:" + id;
        keys.push(key);
        entries[key] = { key: key, folderIndex: -1, favoriteId: id, name: "" };
    });
    var result = [];
    (order || []).concat(keys).forEach(function(key) {
        if (entries[key]) { result.push(entries[key]); delete entries[key]; }
    });
    return result;
}

function move(order, source, target, after) {
    if (source === target) return order.slice();
    var result = order.filter(function(key) { return key !== source; });
    var index = result.indexOf(target);
    result.splice(index < 0 ? result.length : index + (after ? 1 : 0), 0, source);
    return result;
}

function group(folders, order, sourceId, targetKey, newId, name) {
    var copy = folders.map(function(f) { return {id: f.id, name: f.name, items: f.items.slice()}; });
    var target = copy.filter(function(f) { return "folder:" + f.id === targetKey; })[0];
    if (!sourceId || targetKey === "app:" + sourceId) return null;
    if (target && target.items.indexOf(sourceId) >= 0) return null;
    // A move between folders removes the previous membership, without unpinning.
    copy.forEach(function(f) { f.items = f.items.filter(function(id) { return id !== sourceId; }); });
    var nextOrder = order.filter(function(key) { return key !== "app:" + sourceId; });
    if (target) {
        target.items.push(sourceId);
    } else {
        if (targetKey.indexOf("app:") !== 0) return null;
        var targetId = targetKey.slice(4);
        copy.forEach(function(f) { f.items = f.items.filter(function(id) { return id !== targetId; }); });
        target = { id: newId, name: name, items: [targetId, sourceId] };
        copy.push(target);
        nextOrder = nextOrder.map(function(key) { return key === targetKey ? "folder:" + newId : key; });
    }
    return { folders: copy, order: nextOrder };
}

// Stable manual order is preserved while a presentation sort is enabled.
function sorted(entries, mode, nameForEntry) {
    if (mode === 0) return entries;
    return entries.map(function(entry, index) { return {entry: entry, index: index}; })
        .sort(function(a, b) {
            if (mode === 2 || mode === 3) {
                var typeDiff = (a.entry.folderIndex < 0 ? 1 : 0) - (b.entry.folderIndex < 0 ? 1 : 0);
                if (typeDiff) return mode === 3 ? -typeDiff : typeDiff;
            }
            return nameForEntry(a.entry).localeCompare(nameForEntry(b.entry), undefined,
                       {numeric: true, sensitivity: "base"}) || a.index - b.index;
        }).map(function(value) { return value.entry; });
}
