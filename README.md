# HuntsmanWarmaskReminder

HuntsmanWarmaskReminder alerts you when you're wearing the Huntsman War Mask in combat but missing its bonus buff.

## Usage

Type `/hwr` in chat to toggle the warning system on or off.

Additional slash commands:
- `/hwrshow` - Toggle showing the icon outside of combat
- `/hwrstoggletimer` - Toggle the timer display on the icon
- `/hwrstogglewarning` - Toggle the center-screen warning display
- `/hwrresettimercolor` - Reset timer color to default (green)
- `/hwrresetbashcolor` - Reset bash text color to default (white)
- `/hwrresetcooldowncolor` - Reset cooldown timer color to default (red)

## States and Functionality

The addon tracks your bash state and provides different visual feedback based on the current state:

### Tracked Target

When you bash a target, the addon tracks that specific target:
- **Target Name**: Stored to identify the bashed enemy
- **Target Unit ID**: Used to verify the exact target (from combat events)

The tracked target is cleared when:
- You leave combat
- The 60-second debuff expires

During the "can bash" period, bashing a new target will switch tracking to the new target (the original target is replaced, not simply cleared).

### Ready to Bash State (No Active Debuff)

**When**: Before your first bash, or after the 60-second debuff has expired.

**What the addon does**:
- Shows the icon with "Bash" text (white color by default)
- Displays buff timer if the Huntsman Warmask buff is active
- Reminds you that you can and should bash to apply the Mark of Hircine debuff
- Accepts new bashes to start tracking a target

### Cooldown State (First 10 seconds after bash)

**When**: Immediately after bashing, when the debuff has 60-50 seconds remaining.

**What the addon does**:
- Shows a red cooldown timer counting down from 60 to 50 seconds
- **Ignores new bashes** during this period to prevent spam and ensure proper debuff application
- Keeps tracking the original bashed target

**Purpose**: Prevents accidentally bashing multiple targets during the internal cooldown period.

### Can Bash State (Last 50 seconds of debuff)

**When**: When the debuff has 50-0 seconds remaining (after the 10-second cooldown).

**What the addon does**:
- Shows a green timer counting down the remaining debuff time
- Displays "can bash" text next to the timer (if enabled in settings)
- **Accepts new bashes** - bashing a new target will reset the 60-second timer and track the new target
- Timer color changes from red (cooldown) to green (can bash)

**Purpose**: Indicates when you can safely bash a new target to refresh or change the debuff application.

## Visual Indicators Summary

| State | Timer Color | Timer Text | Can Bash New Target? |
|-------|------------|------------|---------------------|
| Ready to Bash | White | "Bash" | Yes |
| Cooldown (60-50s) | Red | Countdown (60-50) | No (ignored) |
| Can Bash (50-0s) | Green | Countdown + "can bash" | Yes |
| Buff Active | Green | Buff remaining time | N/A |

## Settings

All settings are accessible through the addon menu (Settings > Addons > HuntsmanWarmaskReminder).

### Visibility Settings

- **Lock the position of the icon**: When enabled, the icon position is locked and cannot be moved. Disable to reposition the icon by dragging.
- **Show icon outside of combat**: When enabled, the icon and timer are visible even when not in combat.
- **Toggle timer on icon**: When enabled, displays a countdown timer. When disabled, only shows a "bash" reminder.
- **Show "can bash" text**: When enabled, shows "can bash" text next to the debuff timer after the 10-second cooldown period.
- **Show bashed target name**: When enabled, displays the name of the currently debuffed target below the timer.
- **Show "BASH" center-screen instead of icon**: When enabled, displays large text in the center of the screen instead of the movable icon.
- **Horizontal layout**: When enabled, displays the icon on the left with timer/bash/can bash text to the right. When disabled, uses vertical layout with text below the icon.

### Display Settings

- **Icon Size**: Adjust the size of the warning icon (50-200%).
- **Timer Font Size**: Adjust the font size of the timer text (16-128px).
- **Warning Font Size**: Adjust the font size of the center-screen warning text (16-128px).
- **Bashed Target Font Size**: Adjust the font size of the bashed target name text (12-64px).
- **Timer Color (Active Buff)**: Set the color for the timer when buff is active and during can bash period.
- **Bash Text Color**: Set the color for the "Bash" reminder text.
- **Cooldown Timer Color**: Set the color for the cooldown timer (first 10 seconds after bash).

### Font Settings

- **Font Family**: Select the font family to use for the addon text (Univers67 or ProseAntiquePSMT).

## Credits

- Scene management assistance by Duesentrieb
