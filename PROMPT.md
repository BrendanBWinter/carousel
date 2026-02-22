# Carousel — Claude Code Build Prompt

## Project Overview

Build a functional iPadOS prototype of **Carousel**, a task management and idea organisation app designed for people with ADHD. The app is built around a "card" system with multiple visual views for organising and interacting with tasks. The core interaction is a **carousel of suggested cards** that the user pulls from into their daily task list.

This is a **SwiftUI** app targeting **iPadOS 17+**. Use **SwiftData** for local persistence. No backend or server — everything runs locally on-device. Populate the app with realistic seed data so all views are demonstrable immediately on first launch.

---

## 1. Data Model (SwiftData)

### Card
The fundamental data unit. Every task, idea, and item in the app is a Card.

```
Card:
  - id: UUID
  - title: String
  - body: String (optional, longer description / notes)
  - createdAt: Date
  - dueDate: Date? (optional deadline)
  - tags: [String] (freeform tags for categorisation)
  - spoons: Int (1–5, effort/energy cost — based on spoon theory)
  - importance: Int (1–5, how important this is)
  - isCompleted: Bool
  - completedAt: Date?
  - isInToday: Bool (whether the user has pulled this into their today view)
  - addedToTodayAt: Date? (when it was pulled into today)
  - isRepeating: Bool
  - repeatInterval: String? ("daily", "weekly", "monthly", or nil)
  - parentCard: Card? (for nesting — cards within cards)
  - childCards: [Card] (inverse relationship)
  - category: String? (e.g. "personal", "work", "health", "creative")
```

### UserSettings (single instance)
```
UserSettings:
  - dailySpoonBudget: Int (default 10)
  - hasCompletedOnboarding: Bool
  - enabledViews: [String] (which views are visible: "calendar", "bubbles", "list", "checkin")
  - preferredTheme: String ("liquid", "minimal", "warm")
  - reduceAnimations: Bool (accessibility option)
  - carouselMode: String ("smart" or "linear")
  - firstLaunchDate: Date?
  - lastActiveDate: Date?
```

### DailyLog (for check-in / coaching analytics)
```
DailyLog:
  - id: UUID
  - date: Date
  - spoonsPlanned: Int (total spoons of tasks pulled into today)
  - spoonsCompleted: Int (total spoons of completed tasks)
  - tasksPlanned: Int
  - tasksCompleted: Int
  - note: String? (optional user reflection)
```

---

## 2. App Structure & Navigation

The app uses a **spatial navigation model** centred on a Home/Overview screen. On iPad, multiple panels are visible simultaneously. Navigation between major views uses **swipe gestures from the edges** and **tab-like controls**.

### View Hierarchy (iPad landscape layout)

The Home screen is the default. From Home, the user can reach all other views:

```
                    [Check-In]
                        ↑ (swipe up or tap)
                        |
[Bubble View] ← ——— [HOME] ——— → [Calendar View]
                        |
                        ↓ (pull carousel down or tap)
                    [List/Kanban View]
```

**Home screen layout on iPad (landscape):**
```
┌─────────────────────────────────────────────────────┐
│  ┌─ edge glow ─┐                    ┌─ edge glow ─┐│
│  │ (bubbles)   │   TODAY VIEW        │ (calendar)  ││
│  │  peek       │                     │  peek       ││
│  │             │   [cards placed     │             ││
│  │             │    here by user]    │             ││
│  │             │                     │             ││
│  └─────────────┘                    └─────────────┘│
│                                                     │
│  ┌─────────── CAROUSEL ───────────────────────────┐ │
│  │  ← [card] [card] [card] [card] [card] [+] →    │ │
│  └─────────────────────────────────────────────────┘ │
│                                                     │
│  [Quick entry: "What do you want to do?" ] [+]     │
└─────────────────────────────────────────────────────┘
```

### Navigation Implementation

- **Left edge:** A subtle glowing strip (not a solid bar — see Visual Design). Tapping or swiping right-to-left from here opens the **Bubble View** as a full overlay/panel.
- **Right edge:** Same treatment. Opens the **Calendar View**.
- **Carousel pull-down:** Dragging the carousel strip downward (or tapping a small tab peeking below it) reveals the **List/Kanban View** sliding up from the bottom as a sheet.
- **Top area:** A small tab or button for the **Check-In** view, accessible as a sheet sliding down from the top.
- **"+" button:** Persistent in the top-right corner. Opens the full **New Card** creation view as a modal sheet.
- **Quick entry bar:** At the bottom of the Home screen. A text field with placeholder "What do you want to do?" — hitting return creates a card with defaults. The "+" next to it expands to the full New Card sheet.

Use SwiftUI's `.gesture()` modifiers for swipe detection, `.sheet()` and `.fullScreenCover()` for view transitions. All transitions should animate fluidly (see Visual Design).

---

## 3. View Specifications

### 3.1 Home / Overview

The central hub. Always shows:
1. **Today area** (main panel, centre): Displays cards the user has pulled in for today. Initially blank each day. Cards appear as rounded, slightly translucent rectangles with the card title, spoons indicator (small spoon icons), and a completion checkbox. Completed cards get a strikethrough and fade to lower opacity. Cards can be reordered by dragging.
2. **Spoon budget bar** (top of today area): Shows "X / Y spoons" with a visual bar. X = spoons committed (sum of today's cards), Y = daily budget. The bar fills with a gradient. When overloaded (X > Y), the bar turns amber/red and gently pulses.
3. **Carousel strip** (bottom): Horizontally scrollable row of card previews. See §3.2.
4. **Edge indicators** (left and right): Subtle animated glows hinting at the Bubble and Calendar views. See Visual Design §5.
5. **Quick entry bar** (very bottom): Text field + expand button.

**Daily reset logic:** On each new calendar day (check via `lastActiveDate` in UserSettings), set `isInToday = false` for all non-repeating cards. For repeating cards, create a fresh copy if needed. Log yesterday's stats to DailyLog.

### 3.2 The Carousel

**This is the most important single feature.** The carousel is a horizontally scrollable strip at the bottom of the Home screen.

**Layout:** Cards appear as smaller preview tiles (roughly 120×90pt on iPad) showing:
- Card title (truncated to 2 lines)
- Spoon cost (small spoon icons)
- A coloured left-edge stripe based on category
- Due date if set (relative: "today", "tomorrow", "in 3 days")

**Scrolling:** Standard horizontal ScrollView with `.scrollTargetBehavior(.viewAligned)` for snap-to-card feel. The strip has a slight **curved perspective** — cards at the centre are slightly larger, cards towards the edges slightly smaller and rotated (use `.rotation3DEffect` with a scroll-position-based angle). This gives the "carousel" / arc feel from the wireframe.

**Interaction — pulling cards into Today:**
- **Tap** a carousel card to see a quick detail popup (card title, full description, spoons, due date, tags).
- From the popup, tap **"Add to Today"** to pull it into the today view. The card animates upward from the carousel into the today area (use `matchedGeometryEffect` if feasible, otherwise a custom position animation).
- Alternatively, implement **drag-and-drop**: long-press a carousel card, then drag it upward into the today area. On drop, it becomes a today card. Use `.draggable()` and `.dropDestination()`.

**Smart shuffle (carouselMode == "smart"):**
Cards are sorted by a weighted score:
```
score = (importanceWeight * importance) + (urgencyWeight * urgencyFactor) + (varietyBonus)

where:
  urgencyFactor = max(0, 10 - daysUntilDue) for cards with due dates; 3 for cards without
  varietyBonus = small random factor (0–2) to prevent identical ordering each day
  importanceWeight = 2.0
  urgencyWeight = 1.5
```
Repeating daily cards always appear. Completed cards are excluded. Already-in-today cards are excluded.

**Linear mode (carouselMode == "linear"):** Simply sorted by due date (soonest first), then by creation date.

**The "+" at the end of the carousel** opens the New Card sheet (same as the persistent "+" button).

### 3.3 Today View / Day Ahead

The main working area occupying the centre of the Home screen.

- Displays a vertical `LazyVStack` of today's cards (where `isInToday == true` and `addedToTodayAt` is today).
- Each card row shows: checkbox, title, spoon indicators (small spoon icons), category colour dot, and a "..." menu for edit/remove/complete.
- **Tapping** a card opens its detail view (see §3.8).
- **Checkbox** marks the card complete with a satisfying animation (the card briefly glows, then fades to a muted/struck-through state, slides to the bottom of the list).
- **Empty state:** When no cards are in today, show a friendly message: "Your day is clear. Pull something from the carousel when you're ready." with a subtle downward arrow animation pointing at the carousel.
- Cards are **reorderable** via drag handles (explicit grab handle icon on the right side of each card — NOT press-and-hold on the whole card, to avoid the scroll/drag tension issue).

### 3.4 Calendar View

Accessed from the right edge of the Home screen. Slides in as a panel (on iPad, it can push the today view to the left, or overlay it).

**Structure:**
- A **segmented control** at the top: Day | Week | Month | Year
- **Week view (default):** 7 columns for the days, with card titles listed in each day cell. Compact card representation (just title + category colour dot). Today's column is highlighted.
- **Month view:** Grid of day cells (standard calendar grid). Each day cell shows dots indicating cards exist (coloured by category). Tapping a day shows that day's cards in a popover or side panel.
- **Year view:** 12 mini month grids arranged in a 3×4 or 4×3 layout. Very compact — just showing which days have dots. Tapping a month zooms into month view.
- **Day view:** A single day's full card list, similar to the today view but read-only (you can tap to pull a card into today from here).

Transition between zoom levels should animate smoothly (use `matchedGeometryEffect` or spring animations for the zoom feel).

Cards with due dates populate their respective days. Cards without due dates don't appear in the calendar.

### 3.5 Bubble View / Exploration

Accessed from the left edge of the Home screen. Full-screen overlay or panel.

**Implementation:** A `Canvas` or `TimelineView` + overlaid SwiftUI views. Each card is represented as a **circle/bubble**:
- Size is proportional to importance (importance 5 = large bubble, importance 1 = small).
- Colour is based on category (use a pastel palette).
- Bubbles have the card title centred inside (truncated, small font).
- Bubbles **float and drift** gently — apply slow, continuous, randomised position offsets using `withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true))` with slight random phase offsets per bubble.
- Bubbles should avoid overlapping (basic collision avoidance — if two bubbles are too close, push them apart each frame).
- **Tapping** a bubble opens its detail view.
- If a card has **child cards**, tapping it zooms into a sub-view where the children appear as their own cluster of smaller bubbles (animate the parent bubble expanding to fill the area, then its children appearing inside). A "back" button returns to the main bubble view.
- Group bubbles by category if feasible (clusters form loosely by colour), but don't enforce a rigid grid.

### 3.6 List / Kanban View

Accessed by pulling down on the carousel or tapping a small tab at the bottom edge of the Home screen. Slides up as a large sheet (`.sheet` with large detent or a custom bottom-sheet implementation).

**Layout:** Horizontal columns (3 or 4 visible at a time, horizontally scrollable), where each column represents a **time period**:
- **Overdue** (leftmost, tinted red)
- **Today**
- **This Week**
- **Upcoming** (next 2 weeks)
- **Someday** (no due date)

Each column is a vertically scrollable list of card tiles. Cards show: title, spoon indicator, category colour stripe, due date.

**Interaction:** Cards can be **dragged between columns** to reassign their timeframe (this updates the card's due date accordingly). Tapping a card opens its detail view.

### 3.7 Check-In / Coaching View

Accessed via a button/tab at the top of the Home screen or swiping down. Presented as a sheet.

**Contents:**
1. **Today's summary:** "You've completed X of Y tasks (Z spoons used of W budget)." with a progress ring or bar.
2. **Weekly trend:** A small bar chart (7 bars, one per day) showing spoons completed vs. planned for the last 7 days. Use SwiftUI `Charts` framework.
3. **Coaching messages:** Context-aware, friendly messages based on patterns in DailyLog data. Implement as a function that evaluates recent logs:
   - If average `spoonsPlanned > dailySpoonBudget * 1.2` for the last 5 days: "You've been consistently planning more than your spoon budget. That's a lot — maybe try scaling back a little tomorrow?"
   - If `tasksCompleted / tasksPlanned < 0.4` for the last 5 days: "Finishing fewer tasks than you planned isn't failure — it might mean your estimates need adjusting. Try pulling fewer cards tomorrow."
   - If `lastActiveDate` was more than 2 days ago: "Welcome back! No pressure — maybe just pick one small thing from the carousel today."
   - If the user has been active for 7+ consecutive days: "You've been at this for a whole week. That's genuinely impressive. Keep going."
   - If the user adds more than 8 cards to today in one session: "That's a lot for one day. Remember — anything you don't finish just goes back to the carousel. No pressure."
   - Default / no pattern: "You're doing fine. One thing at a time."
4. **Spoon budget adjuster:** A stepper control to adjust the daily spoon budget, with a note: "This is just a guideline for yourself — not a limit."

**Settings access guardrail:** If the user opens Settings within their first day of use, show a gentle banner at the top of Settings: "You've only just started — maybe try using it for a day or two before tweaking things?" with a "Got it" dismiss button. This is informational, not blocking. Don't show this banner again after day 3.

**Voluntary settings cooldown (optional, implement if time permits):** In Settings, include a toggle: "Hide settings for a few days." When enabled, the settings gear icon disappears from the Home screen for 3 days. A small countdown label appears in its place: "Settings back in 2 days." This is for users who know they'll fiddle endlessly instead of actually using the app.

### 3.8 Card Detail View

A modal sheet shown when tapping any card from any view.

**Layout:**
- **Title** (large, editable text field)
- **Body** (multiline editable text area, placeholder: "Add notes...")
- **Spoons** (row of 5 spoon icons — tap to set 1–5; filled spoons are solid, empty are outlined)
- **Importance** (row of 5 star or diamond icons, same tap-to-set interaction)
- **Category** (horizontal row of labelled colour chips: Personal, Work, Health, Creative, Other — tap to select)
- **Tags** (horizontal scrolling chips showing existing tags, with a "+" to add a new tag via text input)
- **Due Date** (date picker, with a "None" option to clear it)
- **Repeating** (toggle + interval picker: Daily / Weekly / Monthly)
- **Sub-cards** (a mini list of child cards, with an "Add sub-task" button)
- **Delete button** (destructive, with confirmation alert)
- **"Add to Today" / "Remove from Today"** button (contextual)

### 3.9 New Card Sheet

Same layout as the Card Detail View, but with empty fields and the title field focused for immediate typing. The "What do you want to do?" placeholder in the title field.

Defaults for new cards: spoons = 1, importance = 1, category = nil, no due date, not repeating.

---

## 4. Onboarding Flow

**Triggered on first launch** (when `hasCompletedOnboarding == false`).

This is NOT a questionnaire. It is a **show-don't-tell walkthrough:**

1. **Screen 1:** Full-screen welcome. Friendly, warm copy: "Hey. This is Carousel. It's here to help you get through your day, one thing at a time." Button: "Show me" / "Skip" (small, bottom corner).
2. **Screen 2:** The Home screen appears with the today area empty and the carousel populated with 5 pre-made example cards. A translucent overlay tooltip points at the carousel: "These are your suggestions for today. Tap one to take a look, or drag it up when you're ready." The user interacts with a real carousel card. Once they add one to today, proceed.
3. **Screen 3:** Tooltip points at the today area: "This is your day. Everything here gets cleared tonight, so don't worry about perfection." Tap to continue.
4. **Screen 4:** Tooltip points at the spoon bar: "Each task costs energy. This keeps track so you don't overload yourself." Tap to continue.
5. **Screen 5:** "That's the basics. You can explore the rest at your own pace." Buttons: "I'm good — let's go" (primary) / "Show me what else there is" (secondary, briefly flashes the edge indicators for bubbles/calendar).

Set `hasCompletedOnboarding = true` and `firstLaunchDate = Date()`.

After 2 days of use, show a **one-time, dismissible banner** at the top of the Home screen: "You've been at it for a couple of days. Want to review your setup?" with buttons: "Sure" (opens settings) / "Not now" (dismisses permanently).

---

## 5. Visual Design System

### Colour Palette
```swift
extension Color {
    // Backgrounds
    static let carouselBg = Color(red: 0.06, green: 0.06, blue: 0.12)         // very dark blue-black
    static let cardBg = Color.white.opacity(0.08)                               // translucent card surface
    static let todayBg = Color.white.opacity(0.04)                              // subtle today area
    
    // Category colours (pastel, semi-transparent for bubbles)
    static let catPersonal = Color(red: 0.55, green: 0.75, blue: 1.0)          // soft blue
    static let catWork = Color(red: 1.0, green: 0.75, blue: 0.55)              // soft amber
    static let catHealth = Color(red: 0.55, green: 1.0, blue: 0.75)            // soft green
    static let catCreative = Color(red: 0.85, green: 0.65, blue: 1.0)          // soft purple
    static let catOther = Color(red: 0.9, green: 0.9, blue: 0.9)              // light grey
    
    // Accents
    static let spoonFilled = Color(red: 1.0, green: 0.85, blue: 0.4)          // warm gold
    static let spoonEmpty = Color.white.opacity(0.2)
    static let overloaded = Color(red: 1.0, green: 0.5, blue: 0.4)            // soft red
    static let success = Color(red: 0.4, green: 0.9, blue: 0.6)               // completion green
}
```

### Card Styling
Every card surface (in carousel, today view, list, detail) should:
- Have a **blurred glass background** (`.ultraThinMaterial` or custom `Material`).
- Have **rounded corners** (`cornerRadius: 16`).
- Have a **subtle border** (1pt, white at 0.15 opacity).
- Cast a **soft shadow** (`.shadow(color: .black.opacity(0.3), radius: 8, y: 4)`).
- Have a **category colour strip** on the left edge (4pt wide rounded rectangle, inset).

### Fluid / Liquid Glass Aesthetic
The overall feel should be dark, glassy, and fluid — inspired by Apple's Liquid Glass and the DreamZ PS4 game:

- **Background:** Use a very dark gradient (near-black to deep navy) with a subtle animated noise texture or very slow-moving gradient shift (use `TimelineView(.animation)` to slowly rotate a gradient's angle over 30+ seconds).
- **Card edges:** Apply a very subtle **wobble animation** to card borders. Implement with a custom `Shape` that uses `sin()` offsets along the edge path, animated with a slow repeating timer. The wobble should be gentle — amplitude of ~1pt, frequency of 3-4 waves per edge. Use `TimelineView` + `Canvas` or a custom `Shape` with animated phase.
- **Edge navigation indicators:** Instead of solid bars, render 8–12 small **glowing dots** scattered along each edge. Each dot is a small circle (4–6pt) with a radial gradient (bright centre, transparent edge) that **pulses** independently at different rates (randomise `animation` durations between 1.5–3 seconds). These should feel like "fireflies" or "glowworms."
- **Transitions:** All view transitions should use `.spring(response: 0.5, dampingFraction: 0.75)` for a fluid, slightly bouncy feel. Avoid harsh cuts.

### Animations
- **Card completion:** Checkbox fills → card briefly glows (scale up 1.02x with a bright border flash) → text gets strikethrough → card fades to 0.5 opacity → slides to bottom of list. Total duration: ~0.8s.
- **Card pull from carousel to today:** Card preview lifts out of carousel (slight scale-up + shadow increase) → floats upward into today area → settles into position. Duration: ~0.5s.
- **Bubble drift:** Each bubble has a random `(dx, dy)` drift vector. Every ~3 seconds, generate a new random target offset (within ±15pt of centre position). Animate to new position with `easeInOut(duration: 3)`. Stagger start times so bubbles move asynchronously.
- **Carousel 3D arc:** Cards in the carousel use `.rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))` where `angle` is based on horizontal offset from scroll centre (max ±15°). Cards also scale down slightly towards the edges (scale 0.85 at the edges, 1.0 at centre).

### Reduce Animations Mode
When `reduceAnimations == true`:
- Disable wobble effects on card edges (use static rounded rectangles).
- Disable bubble drift (bubbles stay stationary).
- Disable carousel 3D arc (flat horizontal scroll).
- Disable edge glow pulsing (static dots or thin line).
- Reduce all transition durations by 50%.
- Disable background gradient animation.

### Typography
- **Titles / headings:** System font, `.title2` weight `.semibold`.
- **Card titles:** System font, `.body` weight `.medium`.
- **Body text / descriptions:** System font, `.body` weight `.regular`.
- **Small labels (dates, tags):** System font, `.caption` weight `.regular`, slightly lower opacity.
- Use `.foregroundStyle(.white)` as the default text colour (dark theme).

### Spoon Icons
Create a simple custom spoon shape using SwiftUI `Path` (a rounded bowl + handle). Or use `SF Symbols` — the closest is probably a custom rendering. For the prototype, use a simple oval-topped shape. Filled spoons are `spoonFilled` colour; empty spoons are `spoonEmpty`. Each is roughly 16×24pt.

---

## 6. Seed Data

On first launch, populate the database with **15–20 seed cards** across different categories, spoon levels, and timeframes to make the app immediately demonstrable:

```
Category: Personal
  - "Do the grocery shopping" (spoons: 2, importance: 3, due: today, tags: ["errands"])
  - "Call Mum" (spoons: 1, importance: 4, due: tomorrow, tags: ["family"])
  - "Sort out that pile of mail" (spoons: 2, importance: 2, due: this week, tags: ["home"])
  - "Book dentist appointment" (spoons: 1, importance: 3, due: this week, tags: ["health", "admin"])

Category: Work  
  - "Finish the quarterly report" (spoons: 4, importance: 5, due: in 3 days, tags: ["deadline", "writing"])
  - "Reply to Jamie's email" (spoons: 1, importance: 3, due: today, tags: ["email"])
  - "Prepare slides for Thursday meeting" (spoons: 3, importance: 4, due: in 2 days, tags: ["meeting", "presentation"])
  - "Review team timesheets" (spoons: 2, importance: 2, due: this week, tags: ["admin"])

Category: Health
  - "Do your stretches" (spoons: 1, importance: 3, repeating: daily, tags: ["routine", "body"])
  - "30 min walk" (spoons: 2, importance: 3, repeating: daily, tags: ["exercise"])
  - "Take medication" (spoons: 1, importance: 5, repeating: daily, tags: ["routine", "medication"])
  - "Meal prep for the week" (spoons: 3, importance: 3, due: Sunday, tags: ["food", "planning"])

Category: Creative
  - "Sketch out that app idea" (spoons: 2, importance: 2, no due date, tags: ["ideas", "design"])
  - "Write in journal" (spoons: 1, importance: 2, repeating: daily, tags: ["reflection", "writing"])
  - "Research pottery classes" (spoons: 1, importance: 1, no due date, tags: ["hobby", "research"])
  - "Finish reading that book" (spoons: 2, importance: 2, no due date, tags: ["reading"])

Nested example:
  - "Plan the weekend trip" (spoons: 3, importance: 3, due: next week)
    - Child: "Book accommodation"
    - Child: "Check train times"  
    - Child: "Pack bag"
```

Also seed 5 days of `DailyLog` data with slightly varied completion rates so the Check-In charts and coaching messages have data to work with immediately.

---

## 7. Settings View

Accessible from a gear icon in the top-left of the Home screen. Presented as a `.sheet`.

**Sections:**
1. **Your Day:** Daily spoon budget stepper (range 5–20, default 10).
2. **Views:** Toggles to show/hide each non-essential view (Bubble View, Calendar View, List View, Check-In). The Today + Carousel are always on.
3. **Carousel:** Segmented control for "Smart" vs "Linear" mode.
4. **Appearance:** 
   - Theme picker (Liquid Glass / Minimal / Warm — for prototype, just change accent colours and background)
   - "Reduce animations" toggle
5. **Data:**
   - "Reset onboarding" button (for demo purposes — re-triggers the walkthrough)
   - "Clear all cards" button (with confirmation)
   - "Load sample data" button (reloads seed data)

---

## 8. Key Interactions Summary

| Action | Gesture | Result |
|--------|---------|--------|
| Add card to today | Tap carousel card → "Add to Today" button in popup, OR drag from carousel upward | Card appears in today view, animates from carousel |
| Complete card | Tap checkbox on today card | Card animates to completed state, slides to bottom |
| Open card detail | Tap any card in any view | Modal sheet with full card editor |
| Create new card | Tap "+" button (top-right) or "+" at end of carousel | New Card sheet opens |
| Quick-create card | Type in bottom bar, hit return | Card created with defaults, appears in carousel |
| Open Bubble View | Tap left edge glow, or swipe from left edge | Bubble view slides in from left |
| Open Calendar | Tap right edge glow, or swipe from right edge | Calendar slides in from right |
| Open List View | Tap small tab below carousel, or pull carousel down | List view slides up from bottom |
| Open Check-In | Tap button at top, or swipe down from top | Check-in sheet drops down |
| Reorder today cards | Drag via explicit handle on right side of card | Card reorders in list |
| Move card in List view | Drag card between time-period columns | Card's due date updates |
| Explore bubbles | Tap a bubble with children | Zooms into child bubbles |

---

## 9. File Structure

```
Carousel/
├── CarouselApp.swift                 // @main, SwiftData container setup, seed data check
├── Models/
│   ├── Card.swift                    // SwiftData @Model
│   ├── UserSettings.swift            // SwiftData @Model (singleton)
│   └── DailyLog.swift                // SwiftData @Model
├── Views/
│   ├── HomeView.swift                // Main hub: today + carousel + edge indicators
│   ├── TodayView.swift               // Today's card list with spoon bar
│   ├── CarouselView.swift            // Horizontal scrolling card carousel with 3D arc
│   ├── CalendarView.swift            // Day/Week/Month/Year calendar
│   ├── BubbleView.swift              // Floating bubble exploration
│   ├── ListView.swift                // Kanban-style time columns
│   ├── CheckInView.swift             // Stats, charts, coaching messages
│   ├── CardDetailView.swift          // Full card editor sheet
│   ├── NewCardView.swift             // New card creation sheet
│   ├── SettingsView.swift            // App settings
│   ├── OnboardingView.swift          // First-launch walkthrough
│   └── QuickEntryBar.swift           // Bottom text field for rapid card creation
├── Components/
│   ├── CardTile.swift                // Reusable card tile (used in carousel, today, list)
│   ├── SpoonIndicator.swift          // Row of spoon icons (filled/empty)
│   ├── SpoonBudgetBar.swift          // Budget bar for today view header
│   ├── CategoryChip.swift            // Coloured category selector chip
│   ├── EdgeGlow.swift                // Animated firefly edge indicators
│   ├── WobblyShape.swift             // Custom Shape with animated wobbly edges
│   ├── CoachingMessage.swift         // Logic + display for coaching messages
│   └── BubbleNode.swift              // Individual bubble in the bubble view
├── Utilities/
│   ├── CarouselSorter.swift          // Smart/linear sorting logic for carousel
│   ├── SeedData.swift                // Seed card and DailyLog generation
│   └── DateHelpers.swift             // Date comparison helpers (isToday, isThisWeek, etc.)
└── Assets.xcassets/                  // App icon, any static assets
```

---

## 10. Implementation Priorities

Build in this order to ensure a functional demo at every stage:

1. **Data model** — Card, UserSettings, DailyLog with SwiftData
2. **Seed data** — populate on first launch
3. **Home screen skeleton** — today view (empty state) + carousel strip (flat, no 3D yet) + quick entry bar
4. **Card detail view** — full editor sheet
5. **Carousel interaction** — tap to preview, "Add to Today" button, smart sort
6. **Today view** — card list, completion, spoon budget bar, daily reset
7. **Calendar view** — week + month views with segmented control
8. **List/Kanban view** — time-period columns
9. **Bubble view** — floating circles with drift animation
10. **Check-in view** — stats, charts, coaching messages
11. **Visual polish** — wobble effects, 3D carousel arc, edge glows, glass materials, transitions
12. **Onboarding flow** — walkthrough screens
13. **Settings** — all configuration options
14. **Drag-and-drop** — carousel to today, list column reassignment

---

## 11. Critical Design Principles (Reference Throughout)

These principles should guide every implementation decision:

1. **Object permanence:** On iPad, always show hints of adjacent views (edge glows, peeks). Never make the user wonder "where did that go?" The UI should always communicate what exists and where.
2. **Single-purpose controls:** Every tappable element does ONE thing. No context-dependent gestures. The drag handle is a drag handle. The checkbox is a checkbox. No press-and-hold as the only way to access a function.
3. **Clarity over cleverness:** If a gesture is ambiguous, replace it with a visible button. The user should never have to remember how something works.
4. **Friendly, not clinical:** Placeholder text, coaching messages, and labels should sound like a supportive friend, not a productivity guru or a therapist. Examples: "What do you want to do?" not "New task." "Your day is clear" not "No tasks scheduled."
5. **Breathing room:** Don't cram the screen. Use generous padding (16–20pt between elements). White space is a feature, not a waste.
6. **Fluid, not static:** Everything should feel alive. Gentle animations, soft transitions, subtle movement. But always with a "reduce animations" escape hatch.
7. **Daily reset:** The today view clears every day. This is a feature, not a bug. Yesterday is gone. Today is fresh.

---

## 12. Deferred Features (Do Not Build, But Design With These in Mind)

The following are planned for future versions. Don't implement them, but don't make architectural choices that would make them impossible later:

1. **Body Doubling Companion App:** A separate companion app featuring a virtual "buddy" character who works alongside the user and sends encouraging check-in notifications. The main Carousel app should eventually be able to share card data with this companion via shared App Group containers or inter-app communication. For now, just ensure the SwiftData model container could theoretically be shared.

2. **Professional Plugin Modules:** Paid extensions (teacher planner, contractor tools, etc.) that add custom card data types, pre-made configurations, and specialised views. The Card model's flexible `tags` and `category` fields are a foundation for this — don't restrict them to a fixed enum.

3. **Templates / Presets:** Pre-configured app setups for different professions or use cases. The `enabledViews` array in UserSettings and the modular view architecture already support this conceptually.

4. **Calendar Integration:** Syncing with Apple Calendar / EventKit. Keep the calendar view's data sourced from Cards for now, but the CalendarView's architecture should not assume cards are the only source of events.

5. **iPhone Layout:** The prototype targets iPad landscape. A future iPhone version would show only one panel at a time (Today + carousel at bottom), with the other views accessible via a bottom tab bar or swipe navigation rather than spatial edge gestures. Use `@Environment(\.horizontalSizeClass)` in key layout views so this adaptation is easier later.
