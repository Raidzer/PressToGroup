# PressToGroup 0.1.15

[Русская версия](README.ru.md).

A Mythic+ premade group finder assistant for WoW Retail 12.1.5. A standalone addon built on the native WoW API, with no third-party libraries.

This is an early experimental release. Automated tests cover the logic; game input handling and LFG permissions, especially in combat, still require in-game validation.

## Installation

Copy the `PressToGroup` folder from the ZIP into `_retail_/Interface/AddOns/`. The final path should be `_retail_/Interface/AddOns/PressToGroup/PressToGroup.toc`. Restart the game, or use `/reload` if the addon folder was already installed, and enable the addon in the AddOns list.

If you download the source using **Code → Download ZIP** on GitHub, rename `PressToGroup-main` to `PressToGroup` before copying it.

The `Media` folder containing the icon is included. The icon appears in the WoW AddOns list and the `/ptg` window title.

Left-click the minimap icon to show or hide the addon window, just like `/ptg`. EllesmereUI picks it up in its minimap button menu; without EllesmereUI, it stays beside the minimap. Clicking this button does not start the assistant or perform an LFG step.

## Getting started

The **PTG** button in the native Group Finder also shows or hides the assistant. It appears beside PGF when installed, or in the search panel header without PGF. It does not start a search.

1. Type `/ptg`, open Settings, and choose your dungeons, minimum leader rating, search languages, and group composition filters. Your role follows the active specialization automatically by default, including when upgrading existing settings. All dungeons are selected initially. Unchecking a dungeon excludes it; clearing every checkbox pauses the search. The **All** button selects the entire list.
2. Open the native Group Finder using the addon button. Set the key level or range in Blizzard's search box and run a search once. The addon reuses this condition and displays it in its window; it does not write to the protected search box.
3. Close the native window and click **Start**. Subsequent presses of standard Blizzard action buttons perform one available step at a time: search, apply, or cancel an application.
4. To perform a manual step, click **Next step** or assign a key in the PressToGroup section of the game's key binding settings. Accept invitations through the game's invitation dialog.

Before launch, the main window automatically shows four setup steps and the current step number. Once setup is complete, the guide hides and the ready status explains how to run the search.

Settings use a single scrolling page styled like the main window, with four sections: Role and search, Group composition, Season dungeons, and Languages. Controls keep their existing behavior.

The interface language follows your client automatically or can be set to Russian or English. It does not change the search languages; Blizzard's required languages are preserved.

The three role buttons remain available in Settings. Clicking one chooses that role and turns off automatic selection. Turning automatic selection back on uses the active specialization's role; turning it off keeps the current role. The mode is saved per character. If the specialization's role is not yet known, wait for its data or choose a role manually.

Set **Replace application after, sec.** to a positive whole number of seconds (default: 180). The setting is saved per character; changes apply to existing applications without a fresh search. Invalid input, including zero, restores the previous value.

The dark assistant window shows the main status, current role and selection mode, counts of found and eligible groups, the next group, and up to five applications. Hover over shortened names to see their full text. Submitting or cancelling an application remains pending until the client confirms it. The close button and Esc only hide the window; the assistant keeps running.

Click **−** beside the close button to switch to a compact panel with the status, application count, and a **+** button to expand it. Hover over the status for the full reason. The mode and shared position are saved per character; both views can be dragged, and the window stays within the screen edges. Errors and invitations do not expand it automatically. Collapsing closes Settings and discards unfinished numeric input; search and application behavior stays the same.

## Behavior

- Eligible groups are considered from newest to oldest. Checks include your role, available slots, character requirements, and the leader's rating.
- An actual role change requires a fresh search before applying again. Changing only the automatic/manual mode while keeping the same role does not. Existing applications keep the role they were submitted with.
- Composition filters include your own character. A tank must still be present or supplied by you. Missing Bloodlust / Heroism can be recruited into a healer or damage slot remaining after you join; battle resurrection can use any remaining role. If both effects are required and neither is present, two slots are needed, including at least one healer or damage slot. Only available slots reported by the game count; unknown information does not confirm recruitment capacity. Capabilities are inferred from known classes, without checking cooldowns, talents, or pets or guaranteeing the future composition.
- The assistant respects the client's application limit, up to five at once, including manual applications. A confirmed application submitted by the assistant can be replaced after the selected time without a response (180 seconds by default) if another eligible group is available: one press cancels it, and a separate later press submits the replacement after cancellation is confirmed.
- While the assistant is running, a confirmed application it submitted is cancelled on the next press if the group's actual members have filled the role used for that application. This does not require waiting for the selected time or having a replacement ready. Reserved slots and unknown composition data do not trigger early cancellation. Invitations and existing pauses take priority, and the slot is freed only after the client confirms cancellation.
- Manual applications and applications of unknown origin after `/reload` are never cancelled automatically. **Stop** leaves submitted applications in place. After login, `/reload`, or leaving a group, you must start the assistant explicitly.
- Searches can repeat after 8 seconds. Reported search errors increase the delay through 8, 16, 32, and 60 seconds. A new press is required after the delay; timers only update state.
- An open native Group Finder, an invitation, or `ChatMessagingLockdown` restrictions pause actions. Joining a group stops the assistant. After closing the native Group Finder, fresh results are required.
- Search responses have no request identifier. An ambiguous external search or no response within 12 seconds blocks further actions until `/reload`; you must then start the assistant again. A normal manual search in the native window, when the assistant is not waiting for a response, is handled as a pause when its results arrive.

## Commands and diagnostics

The **Log** button at the bottom of Settings prints the current state and diagnostic log to chat.

| Command | Action |
| --- | --- |
| `/ptg` | Show or hide the window |
| `/ptg start` | Start the assistant |
| `/ptg stop` | Stop the assistant, keeping submitted applications |
| `/ptg status` | Print the current state and diagnostic log |
| `/ptg log` | Print the current state and diagnostic log |

Settings, window position, and a short log are saved per character. The log does not record player names or listing titles. Active applications are read from the client; ownership by the assistant is tracked only within the current session.

## Limitations

This version handles input from standard Blizzard action bars; custom action bars are not supported. Automated tests cannot confirm hardware input context, the absence of blocked actions, or LFG behavior in combat. The addon does not bypass client restrictions or accept invitations.
