# PressToGroup 0.1.29-beta.1

[Русская версия](README.ru.md).

A Mythic+ premade group finder assistant targeting WoW Retail 12.1.5 (`Interface: 120105` in the TOC). A standalone addon built on the native WoW API, with no third-party libraries. Support for other patches is not declared.

This is the first public beta candidate. A solo in-game run has confirmed search, application submission, and cancellation. Automated tests cover the logic; coverage of all input modes, combat, binding persistence after `/reload`, and party scenarios still requires in-game beta testing.

## Installation

Download the ready-to-install `PressToGroup-0.1.29-beta.1.zip` from [GitHub Releases](https://github.com/Raidzer/PressToGroup/releases). Copy the `PressToGroup` folder from that ZIP into `_retail_/Interface/AddOns/`. The final path should be `_retail_/Interface/AddOns/PressToGroup/PressToGroup.toc`. Restart the game, or use `/reload` if the addon folder was already installed, and enable the addon in the AddOns list.

Alternatively, download the source using **Code → Download ZIP** on GitHub and rename `PressToGroup-main` to `PressToGroup` before copying it. Prefer the ready-to-install release ZIP for beta testing.

The `Media` folder containing the icon is included. The icon appears in the WoW AddOns list and the `/ptg` window title.

Left-click the minimap icon to show or hide the addon window, just like `/ptg`. Hiding the main window stops the assistant and keeps submitted applications; reopening requires another click on **Start** to continue. EllesmereUI picks it up in its minimap button menu; without EllesmereUI, it stays beside the minimap. Clicking this button does not start the assistant or perform an LFG step.

## Getting started

The **PTG** button in the native Group Finder also shows or hides the assistant. It appears beside PGF when installed, or in the search panel header without PGF. It does not start a search.

A short welcome appears once per account after entering the world. Choose **Open PressToGroup** to open the assistant or **Got it** to dismiss it; the close button and Escape also dismiss it. Existing users without a recorded welcome see it once after updating. Normal logins keep the main window hidden. After `/reload`, the window reopens in its saved position and full or compact view if the assistant was enabled before the reload, including while paused. The assistant stays stopped until you click **Start**; submitted applications are read from the game, and their previous ownership is not restored. Closing the main window stops the assistant, so a subsequent reload keeps it hidden. You can also open it with `/ptg`, the minimap icon, or the native Group Finder's **PTG** button. The welcome and opening the window do not start the assistant.

1. Type `/ptg`, open Settings, and choose your dungeons, minimum leader rating, search languages, and group composition filters. Your role follows the active specialization automatically by default, including when upgrading existing settings. All dungeons are selected initially. Unchecking a dungeon excludes it; clearing every checkbox pauses the search. The **All** button selects the entire list.
2. Open Group Finder using the addon button. Enter a key range in its search box, such as `10-12` for +10 through +12, `15-15` for only +15, or `18-20` for +18 through +20, and run a search once. The addon reuses this condition and displays it in its window; it does not write to the protected search box.
3. In Settings, choose **Automatic** or **Additional key**. Automatic is the default: standard Blizzard action buttons and keyboard movement, turns, strafing, and jumping advance the assistant. Additional key uses the key assigned directly in PressToGroup Settings: each press performs one available step, and abilities, movement and jump do not advance steps in this mode. **Next step** also works after Start.
4. Close the native window and click **Start**. Each subsequent eligible press performs one available step: search, apply, or cancel an application. **Next step** and the assigned key work in both modes after Start. Accept invitations through the game's invitation dialog.

Before launch, the main window automatically shows four setup steps and the current step number. Once setup is complete, the guide hides and the ready status explains how to run the search.

Settings use a single scrolling page styled like the main window, with four sections: Role and search, Group composition, Season dungeons, and Languages. Controls keep their existing behavior.

For quick selection, click **Dungeons N/M** in the full window's bottom row or beside the application count in compact view. A small panel offers checkboxes and **All**. Selection is shared with Settings and applies immediately; the panel stays open for multiple changes. With none selected, the assistant waits for a choice. The panel's close button or another click on **Dungeons** closes only the picker, preserving the running assistant and submitted applications. Settings and the picker open one at a time. Closing the main window stops the assistant and closes the picker; logging in again or reloading does not reopen the picker automatically.

The binding block appears only when **Additional key** is selected; Automatic hides it without clearing existing bindings. To assign a key or modifier combination, click **Assign** and press it. An occupied key shows its current action and requires confirmation before replacement. Assignment edits the primary PressToGroup step binding and preserves its secondary binding; **Clear primary** removes only the primary. Bindings are saved in the game's currently active account or character binding set and can also be edited in the native key binding settings. Escape, hiding Settings or the assistant, collapsing it, changing input mode, or entering combat cancels unfinished assignment. Assignment and clearing are unavailable in combat.

The input mode is saved per character. Changing it or assigning a key keeps the current search and applications. Neither the key nor **Next step** starts a stopped assistant. Input works with an open full or compact window; closing the main window stops further steps. Automatic movement follows current game bindings and modifiers; holding a key, releasing it, autorun, and mouse movement do not add steps. Typing and key assignment pause automatic input.

You can also search as the leader of a regular party of 2–4 players. Only the leader needs PressToGroup. The assistant submits one shared application and checks available places for every party role. Your role follows PressToGroup Settings; companions use their assigned game roles. Assign any unknown roles before applying. The window shows the party size and role counts. Each player confirms roles in the game's dialog when requested; the assistant waits for that check. The leader accepts invitations in the native dialog.

Changing party members, leader, or roles stops the assistant until you click **Start** again. A party change does not transfer ownership of old applications to the new party. Raids, a full party of five, non-leaders, instance matchmaking groups, offline companions, and unknown party data block actions. The assistant does not create a listing or recruit players into your own listing.

The interface language follows your client automatically or can be set to Russian or English. It does not change the search languages; Blizzard's required languages are preserved.

The three role buttons remain available in Settings. Clicking one chooses that role and turns off automatic selection. Turning automatic selection back on uses the active specialization's role; turning it off keeps the current role. The mode is saved per character. If the specialization's role is not yet known, wait for its data or choose a role manually.

Set **Cancel application after, sec.** to a positive whole number of seconds (default: 180, or 3 minutes), counted from the game's submission confirmation. After that time, the running assistant cancels the old application on the next eligible press only if another eligible group is available. Without a replacement, it keeps the application; a separate press applies after cancellation is confirmed. Filled places may cause earlier cancellation under the existing rules. The setting is saved per character; changes apply to existing applications without a fresh search. Invalid input, including zero, restores the previous value.

The dark assistant window shows the main status, current role and selection mode, counts of found and eligible groups, the next group, and up to five applications. Hover over shortened names to see their full text. Submitting or cancelling an application remains pending until the client confirms it. Closing the full or compact window with the close button, `/ptg`, the minimap icon, the **PTG** button or the window binding stops the assistant and keeps submitted applications. Reopening does not restart it; `/ptg start` opens the window and explicitly starts the assistant. Changing view, closing Settings or the welcome, and temporarily hiding the whole interface with Alt+Z do not stop it. Escape closes the full or compact main window only when the assistant is stopped; while enabled, including temporary pauses, the window stays open. Escape still closes Settings and the welcome and cancels key assignment.

Click **-** beside the close button to switch to a compact panel with the status, application count, and a **+** button to expand it. The close button at the right hides the compact panel and stops the assistant, keeping submitted applications intact. The button beside **+** shows a green play icon to **Start** a stopped assistant or a red square to **Stop** a running one, including while paused. Hover over a button to see its action; the tooltip updates immediately when the state changes. Starting or stopping keeps the panel and submitted applications. Hover over the status for the full reason. The mode and shared position are saved per character; both views can be dragged, and the window stays within the screen edges. Errors and invitations do not expand it automatically. Collapsing closes Settings and discards unfinished numeric input; search and application behavior stays the same.

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
| `/ptg` | Show the window, or close it and stop the assistant |
| `/ptg start` | Open the window and start the assistant |
| `/ptg stop` | Stop the assistant, keeping submitted applications |
| `/ptg status` | Print the current state and diagnostic log |
| `/ptg log` | Print the current state and diagnostic log |

Settings, window position, and a short log are saved per character. The log does not record player names or listing titles. Active applications are read from the client; ownership by the assistant is tracked only within the current session.

## Limitations

Automatic ability input supports standard Blizzard action bars; custom action bars are not supported. Movement and jump use a keyboard observer that propagates input to the game. Automated tests cannot confirm actual propagation, hardware input context, binding persistence, or permission to perform LFG actions from that observer, especially in combat. Shared applications, role confirmation across clients, and party merging also require in-game validation. The addon does not bypass client restrictions or accept invitations.

## Beta feedback and development

Report reproducible problems in [GitHub Issues](https://github.com/Raidzer/PressToGroup/issues). Include the WoW and addon versions, input mode, solo or party context, combat state, reproduction steps, and relevant `/ptg log` output or Lua error. Remove player names, chat, and other personal information before posting.

See [RELEASING.md](https://github.com/Raidzer/PressToGroup/blob/main/RELEASING.md) for developer checks, packaging, and beta smoke tests, and [RELEASE_NOTES.md](https://github.com/Raidzer/PressToGroup/blob/main/RELEASE_NOTES.md) for the prepared beta release description. Lua and Python are development tools; installing the addon does not require them.

By Raidzer. Licensed under the [MIT License](LICENSE).
