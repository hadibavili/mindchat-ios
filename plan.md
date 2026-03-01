# Plan: Extend Cache TTL for Settings & Usage to 30 Days + Background Refresh on Launch

## Problem
Settings and usage caches expire after 5min / 15min respectively. These contain slow-changing data (plan, name, email, subscription, limits) that doesn't need to expire that quickly. The short TTL means cold launches often show a loading spinner while waiting for the network.

## Goal
- Extend the disk-persisted TTL for `.settings` and `.usage` to **30 days**
- On every app launch, **always fetch fresh data in the background** and update the cache silently — so the UI shows cached data instantly, then seamlessly updates if anything changed
- When the user **explicitly changes settings** or **signs out**, invalidate as before

## Changes

### 1. `CacheStore.swift` — Increase TTLs
- Change `.settings` TTL from `5 * 60` (5 min) to `30 * 24 * 60 * 60` (30 days)
- Change `.usage` TTL from `15 * 60` (15 min) to `30 * 24 * 60 * 60` (30 days)

### 2. `SettingsViewModel.load()` — Already correct
The current implementation already does cache-then-network: it reads from cache first, then always fetches fresh from the server. With the longer TTL, the cache will almost always be present on cold launch, so the user gets instant UI. No changes needed here.

### 3. `ChatViewModel.loadSettings()` — Already correct
Same pattern: reads cached settings/usage first (phase 1), then fetches fresh (phase 2). No changes needed.

### 4. `SettingsService` — Add a background refresh method
Add a `refreshInBackground()` method that fetches both settings and usage concurrently, updating the cache. This can be called from the app entry point on every launch to ensure data stays fresh regardless of TTL.

### 5. `ContentView.swift` (MainTabView) — Trigger background refresh
Add a `.task` that calls `SettingsService.shared.refreshInBackground()` when `MainTabView` appears (i.e., on every authenticated app launch). This ensures the long-lived cache is always refreshed silently.

## What stays the same
- `updateSettings()` still invalidates `.settings` cache (forces re-fetch on next access)
- `signOut` still calls `invalidateAll()` via EventBus → clears everything
- In-memory entries are still cleared on invalidation events
- Non-persistent keys (`.conversations`, `.topicsTree`, etc.) keep their current short TTLs

## Files touched
1. `Mind Chat/Utilities/CacheStore.swift` — TTL changes (2 lines)
2. `Mind Chat/Services/SettingsService.swift` — Add `refreshInBackground()` method
3. `Mind Chat/ContentView.swift` — Add `.task` for background refresh
