# Expander Tracker

A simple personal mobile tool for tracking my expander protocol.

This app is intended to help me keep track of daily stretching sessions, forward turns, timers, and nut position changes so I do not accidentally miss turns or do extra turns.

## Purpose

I recently had an FME-style expander placed. The protocol includes two different types of activity:

1. **Stretching turns**
   - Temporary forward-and-back turns.
   - Used to loosen the sutures.
   - Logged for completion tracking.
   - Do **not** change the permanent expander position.

2. **Forward expansion turns**
   - Permanent forward turns.
   - These update the current nut position.
   - Logged with before/after position.

This app is only a personal tracking helper. It does not provide medical advice or make recommendations about treatment.

## Current Features Planned

- Daily home screen showing:
  - Current nut position
  - Stretching sessions completed today
  - Whether a forward turn is due or completed
- Stretching session timer
- Stretching turn count tracking
- Forward turn logging
- Warning before accidental duplicate forward turns
- Calendar or daily log view
- Editable nut position labels
- Manual correction of current position
- Configurable forward-turn schedule
- Local-only storage

## Nut Position System

The expander nut has six possible positions/faces.

Some labels are currently placeholders because I do not yet know all final face names.

Default sequence:

```txt
3a
2
3
4
5
Unknown
```

Forward turns move down this list and wrap back to `3a`. Stretching turns are temporary and do not change the saved current position.

## Running Locally

Open the project in Xcode:

```sh
open ExpanderTracker.xcodeproj
```

Then choose an iPhone or iPhone simulator and press Run.
