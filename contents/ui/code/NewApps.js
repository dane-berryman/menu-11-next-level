// SPDX-License-Identifier: GPL-2.0-or-later
var lifetime = 7 * 24 * 60 * 60 * 1000;

function parse(raw) {
    try {
        var state = JSON.parse(raw);
        if (state && state.initialized === true && Array.isArray(state.known)
                && state.recent && typeof state.recent === "object" && !Array.isArray(state.recent)) return state;
    } catch (e) {}
    return {initialized: false, known: [], recent: {}};
}

function scan(state, installed, now) {
    // Empty models can occur during a refresh; wait for a populated snapshot.
    if (!installed.length) return state;
    var ids = installed.filter(function(id, index) { return id && installed.indexOf(id) === index; });
    var recent = {};
    if (state.initialized) {
        ids.forEach(function(id) {
            var stamp = state.recent[id];
            if (typeof stamp === "number" && now - stamp < lifetime) recent[id] = stamp;
            else if (state.known.indexOf(id) < 0) recent[id] = now;
        });
    }
    return {initialized: true, known: ids, recent: recent};
}

function isNew(state, id, now) {
    var stamp = state.recent[id];
    return typeof stamp === "number" && now - stamp < lifetime;
}

function launched(state, id) {
    var recent = {};
    Object.keys(state.recent).forEach(function(key) { if (key !== id) recent[key] = state.recent[key]; });
    return {initialized: state.initialized, known: state.known.slice(), recent: recent};
}
