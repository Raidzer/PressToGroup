# PressToGroup 0.1.17

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
3. In Settings, choose **Automatic** or **By key**. Automatic is the default: standard Blizzard action buttons and keyboard movement, turns, strafing, and jumping advance the assistant. By key uses the key assigned directly in PressToGroup Settings.
4. Close the native window and click **Start**. Each subsequent eligible press performs one available step: search, apply, or cancel an application. **Next step** and the assigned key work in both modes after Start. Accept invitations through the game's invitation dialog.

Before launch, the main window automatically shows four setup steps and the current step number. Once setup is complete, the guide hides and the ready status explains how to run the search.

Settings use a single scrolling page styled like the main window, with four sections: Role and search, Group composition, Season dungeons, and Languages. Controls keep their existing behavior.

To assign a key or modifier combination, click **Assign** and press it. An occupied key shows its current action and requires confirmation before replacement. Assignment edits the primary PressToGroup step binding and preserves its secondary binding; **Clear primary** removes only the primary. Bindings are saved in the game's currently active account or character binding set and can also be edited in the native key binding settings. Escape, hiding Settings or the assistant, collapsing it, changing input mode, or entering combat cancels unfinished assignment. Assignment and clearing are unavailable in combat.

The input mode is saved per character. Changing it or assigning a key keeps the current search and applications. Neither the key nor **Next step** starts a stopped assistant. Input continues with a hidden or compact window. Automatic movement follows current game bindings and modifiers; holding a key, releasing it, autorun, and mouse movement do not add steps. Typing and key assignment pause automatic input.

You can also search as the leader of a regular party of 2–4 players. Only the leader needs PressToGroup. The assistant submits one shared application and checks available places for every party role. Your role follows PressToGroup Settings; companions use their assigned game roles. Assign any unknown roles before applying. The window shows the party size and role counts. Each player confirms roles in the game's dialog when requested; the assistant waits for that check. The leader accepts invitations in the native dialog.

Changing party members, leader, or roles stops the assistant until you click **Start** again. A party change does not transfer ownership of old applications to the new party. Raids, a full party of five, non-leaders, instance matchmaking groups, offline companions, and unknown party data block actions. The assistant does not create a listing or recruit players into your own listing.

The interface language follows your client automatically or can be set to Russian or English. It does not change the search languages; Blizzard's required languages are preserved.

The three role buttons remain available in Settings. Clicking one chooses that role and turns off automatic selection. Turning automatic selection back on uses the active specialization's role; turning it off keeps the current role. The mode is saved per character. If the specialization's role is not yet known, wait for its data or choose a role manually.

Set **Replace application after, sec.** to a positive whole number of seconds (default: 180). The setting is saved per character; changes apply to existing applications without a fresh search. Invalid input, including zero, restores the previous value.

The dark assistant window shows the main status, current role and selection mode, counts of found and eligible groups, the next group, and up to five applications. Hover over shortened names to see their full text. Submitting or cancelling an application remains pending until the client confirms it. The close button and Esc only hide the window; the assistant keeps running.

Click **−** beside the close button to switch to a compact panel with the status, application count, and a **+** button to expand it. Hover over the status for the full reason. The mode and shared position are saved per character; both views can be dragged, and the window stays within the screen edges. Errors and invitations do not expand it automatically. Collapsing closes Settings and discards unfinished numeric input; search and application behavior stays the same.

## Behavior

- Eligible groups are considered from newest to oldest. Checks include your role, available slots, character requirements, and the leader's rating.
- An actual role change requires a fresh search before applying again. Changing only the automatic/manual mode while keeping the same role does not. Existing applications keep the role they were submitted with.
- Composition filters include everyone in your party. A tank must be present in the target group or your party. Missing Bloodlust / Heroism can be recruited into a healer or damage slot remaining after your whole party joins; battle resurrection can use any remaining role. If both effects are required and neither is present, two slots are needed, including at least one healer or damage slot. Only available slots reported by the game count; unknown information does not confirm recruitment capacity. Capabilities are inferred from known classes, without checking cooldowns, talents, or pets or guaranteeing the future composition. Known item level and rating data for all companions must meet listing requirements; missing data does not confirm eligibility.
- The assistant respects the client's application limit, up to five at once, including manual applications. A confirmed application submitted by the assistant can be replaced after the selected time without a response (180 seconds by default) if another eligible group is available: one press cancels it, and a separate later press submits the replacement after cancellation is confirmed.
- While the assistant is running, a confirmed solo application it submitted is cancelled on the next press if the group's actual members have filled the submitted role. For a shared application, early cancellation requires too few total places for the submitting party; submitted companion roles are not exposed reliably. Neither rule requires waiting for the selected time or having a replacement ready. Reserved slots and unknown composition data do not trigger early cancellation. Invitations and existing pauses take priority, and the slot is freed only after the client confirms cancellation.
- Manual applications and applications of unknown origin after `/reload` are never cancelled automatically. **Stop** leaves submitted applications in place. After login, `/reload`, or leaving a group, you must start the assistant explicitly.
- Searches can repeat after 8 seconds. Reported search errors increase the delay through 8, 16, 32, and 60 seconds. A new press is required after the delay; timers only update state.
- An open native Group Finder, an invitation, or `ChatMessagingLockdown` restrictions pause actions. Joining or changing a party stops the assistant; a leader of a supported party can explicitly start it again. After closing the native Group Finder or recovering unknown party data, fresh results are required.
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

Automatic ability input supports standard Blizzard action bars; custom action bars are not supported. Movement and jump use a keyboard observer that propagates input to the game. Automated tests cannot confirm actual propagation, hardware input context, binding persistence, or permission to perform LFG actions from that observer, especially in combat. Shared applications, role confirmation across clients, and party merging also require in-game validation. The addon does not bypass client restrictions or accept invitations.
