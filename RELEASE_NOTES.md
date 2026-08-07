# Release notes

TestFlight "What to Test" copy, newest first.

## Build 7

**Much faster**
- Switching tabs no longer reloads — the app keeps your place, like Instagram.
- The Events feed opens ~2× faster and loads 3 months at a time as you scroll.
- Photo matching went from one library query per event to a single query for
  the whole window, off the main thread (~7–18× faster).
- No more flash of the old layout before the correct one appears.

**Smoother calendar sheet**
- Dragging the day sheet up/down is now smooth — it used to flash and stutter
  because the sheet resized every frame. It now slides as a single piece.

**Please try**
1. Bounce between Events and Calendar — does it stay exactly where you left it?
2. Drag the calendar day sheet up slowly, then flick it. Smooth both ways?
3. Scroll the Events feed down — older months should load as you go.

## Build 6

**Cleaner Events feed**
- Events with photos = full cards. Errands with no photos now shrink to quiet
  one-line rows (no more big empty placeholders).
- Lots of empty events collapse into one "N events with no photos" line — tap to expand.
- New "All events / Only Photos" toggle up top.

**Calendar**
- Photo events show a photo-count badge.
- One swipe up on the grab bar now expands the day sheet fully (glitch fixed).

**Please try**
1. Events: do hangouts stand out while errands stay quiet? Flip the toggle.
2. Calendar: swipe the day sheet up — smooth? Tap a photo event to open it.

## Build 5
- Search island (Events tab only): search hangouts by name and date.
- Calendar day sheet: pull up to full page; tap an event to see its photos inline.
- Videos now play in the photo viewer instead of showing a still frame.

## Build 4
- Profile screen: change photo and username individually (avatar upload fixed).
- Remove a stray photo from an event (⊖ in the photo viewer).
- Recurring events manager with multi-select.
