# HuntsmanWarmaskReminder

HuntsmanWarmaskReminder alerts you when you're wearing the Huntsman War Mask in combat but missing its bonus buff.

## Usage

Type `/hwr` in chat to toggle the warning system on or off.

## States and Functionality

The addon tracks your bash state and provides different visual feedback based on the current state:

### Tracked Target

When you bash a target, the addon tracks that specific target:
- **Target Name**: Stored to identify the bashed enemy
- **Target Unit ID**: Used to verify the exact target (from combat events)
- **Visual Aids**: If enabled, draws a line to the debuffed target when you aim at them (PvE only)

The tracked target is cleared when:
- You leave combat
- The 60-second debuff expires

During the "can bash" period, bashing a new target will switch tracking to the new target (the original target is replaced, not simply cleared).

### Bashed State (No Active Debuff)

**When**: Before your first bash, or after the 60-second debuff has expired.

**What the addon does**:
- Shows the icon with "Bash" text (white color by default)
- Displays buff timer if the Huntsman Warmask buff is active
- Reminds you that you can/bash should bash to apply the Mark of Hircine debuff
- Accepts new bashes to start tracking a target

### Cooldown State (First 10 seconds after bash)

**When**: Immediately after bashing, when the debuff has 60-50 seconds remaining.

**What the addon does**:
- Shows a red cooldown timer counting down from 60 to 50 seconds
- **Ignores new bashes** during this period to prevent spam and ensure proper debuff application
- Keeps tracking the original bashed target
- Visual line is drawn to the debuffed target if enabled

**Purpose**: Prevents accidentally bashing multiple targets during the internal cooldown period.

### Can Bash State (Last 50 seconds of debuff)

**When**: When the debuff has 50-0 seconds remaining (after the 10-second cooldown).

**What the addon does**:
- Shows a green timer counting down the remaining debuff time
- Displays "can bash" text next to the timer (if enabled in settings)
- **Accepts new bashes** - bashing a new target will reset the 60-second timer and track the new target
- Visual aids continue to show the currently tracked target
- Timer color changes from red (cooldown) to green (can bash)

**Purpose**: Indicates when you can safely bash a new target to refresh or change the debuff application.

## Visual Indicators Summary

| State | Timer Color | Timer Text | Can Bash New Target? |
|-------|------------|------------|---------------------|
| Bashed State | White | "Bash" | Yes |
| Cooldown (60-50s) | Red | Countdown (60-50) | No (ignored) |
| Can Bash (50-0s) | Green | Countdown + "can bash" | Yes |
| Buff Active | Green | Buff remaining time | N/A |

## Line Visual Aid (PvE Only)

The addon can optionally draw a line from your character to the debuffed target. This visual aid helps you quickly identify which enemy has the Mark of Hircine debuff applied.

### How It Works

Due to ESO API limitations, the addon cannot retrieve the world position of arbitrary units by name or ID. The only reliable way to get an enemy's position is when they are under your reticle (crosshair). Therefore:

- **The line only appears when you are looking directly at a target with the Mark of Hircine debuff**
- When you move your reticle away from the debuffed target, the line disappears
- This is useful for confirming which target in a group has the debuff applied

### PvE Only Restriction

This visual aid is **automatically disabled in PvP environments** (Cyrodiil, Imperial City, and Battlegrounds). This is intentional because:

- Drawing lines to enemy players could provide unfair targeting assistance
- Such functionality may violate the ESO Terms of Service in PvP contexts

The addon checks `IsPlayerInAvAWorld()` and `IsActiveWorldBattleground()` and will not draw any lines when either returns true.

### Settings

- **Enable Line**: Draws a line from your character to the debuffed target when looking at them 
