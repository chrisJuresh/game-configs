# game-configs

My Team Fortress 2 and Counter-Strike 2 setup, with a script to restore it on a new Windows PC.

The repo holds only my own files. Third-party mods are linked below. The restore script downloads them itself, taking
the **newest** version of each. If a lookup fails, or you pass `-Pinned`, it installs the exact version I had when this
backup was taken (checked by SHA-256).

## Restore on a new PC

1. Install Steam, log in, and install TF2 and CS2. Launch each game once, then quit.
2. **Close Steam** completely. While Steam runs, Steam Cloud can overwrite the restored files.
3. Clone this repo and run:

   ```powershell
   git clone https://github.com/chrisJuresh/game-configs.git
   cd game-configs
   powershell -ExecutionPolicy Bypass -File .\restore.ps1
   ```

4. Set the launch options the script prints. The TF2 ones are already on the clipboard.
   Go to Steam > Library > right-click the game > Properties > Launch options.

Options: `-Game TF2|CS2` restores one game only. `-Pinned` installs the backed-up mod versions instead of the newest
ones. `-SteamId3 <id>` picks the Steam account if there are several on the PC. `-SkipRegistry` leaves TF2's video
settings alone.

The script backs up every file it replaces to `%LOCALAPPDATA%\game-configs-backup\<timestamp>\`, including the
previous `budhud` folder and the previous TF2 registry settings.

## External sources

| What | Source | Backed-up version | Installed as |
|---|---|---|---|
| mastercomfig (performance config, preset **low**) | [github.com/mastercomfig/mastercomfig](https://github.com/mastercomfig/mastercomfig) · [releases](https://github.com/mastercomfig/mastercomfig/releases) · [docs](https://docs.comfig.app/latest/) | [9.100.1](https://github.com/mastercomfig/mastercomfig/releases/tag/9.100.1) | `tf/custom/mastercomfig-base.vpk` |
| mastercomfig addons: flat-mouse, no-tutorial, null-canceling-movement | same release | 9.100.1 | `tf/custom/mastercomfig-addon-*.vpk` |
| budhud (HUD) | [github.com/rbjaxter/budhud](https://github.com/rbjaxter/budhud) | [`16f7be2`](https://github.com/rbjaxter/budhud/tree/16f7be2bb4f0dcbe46ec5f444486ab6a6ea4c7e6) (release [2511_01](https://github.com/rbjaxter/budhud/releases/tag/2511_01) + one README commit) | `tf/custom/budhud/` |
| Tiago's No explosion smoke script | [gamebanana.com/mods/678380](https://gamebanana.com/mods/678380) | file [1705517](https://gamebanana.com/dl/1705517) | `tf/custom/tiago_no_explosion_smoke.vpk` |
| Rocket + Sticky Jumper remove explosion smoke | [gamebanana.com/mods/646386](https://gamebanana.com/mods/646386) | file [1603165](https://gamebanana.com/dl/1603165) | `tf/custom/noJumperSmoke.vpk` |

To do it by hand instead of using the script, download each item above into `tf/custom/`, then copy `tf2/game/`
over the TF2 install folder.

## What's in the repo

### TF2 (`tf2/`)

`tf2/game/` mirrors the TF2 install folder (`steamapps/common/Team Fortress 2/`).

- `tf/cfg/overrides/autoexec.cfg`: personal settings that mastercomfig runs after its own config.
  - FOV 90 and min viewmodels.
  - Hitsounds and killsounds.
  - Damage numbers, with a batching window set per class.
  - Auto demo recording (`ds_enable 2`).
  - Loads the hide-primary script and the class mouse binds.
- `tf/cfg/overrides/hide_primary.cfg`: hides the viewmodel only while the primary (slot 1) is out. It tracks the slot
  through number keys, mouse wheel, Q (last weapon) and Soldier's banner auto-switch.
- `tf/cfg/overrides/<class>.cfg`: per-class damage-number batching, wheel order for the hide-primary script, and
  MOUSE4/MOUSE5 binds.
  - Spy: MOUSE4 last disguise, MOUSE5 undisguise.
  - Engineer: MOUSE4 sentry blueprint.
  - All other classes: MOUSE4 unbound, MOUSE5 voice.
- `tf/cfg/overrides/setup_hook.cfg`: `preset=low`. It runs after the comfig app's `preset=high`, so low wins.
- `tf/cfg/config.cfg`: TF2's saved config (binds, sensitivity 0.75, crosshair and the rest). The script also writes
  it to the Steam Cloud copy (`userdata/<id>/440/remote/cfg/config.cfg`), because TF2 loads that copy too.
- `tf/custom/comfig-custom/cfg/app/`: what the [comfig app](https://comfig.app/) generated (addons list and preset).
- `tf/custom/budhud/`: my edits that go on top of budhud.
  - `#users/custom/resource/ui/hudplayerhealth.res` and `#users/custom/scripts/hudanimations_custom.txt`: a vertical
    health bar next to the health number. It is green normally, blue when overhealed, and red with a flashing track
    when health is low.
  - `materials/hud/health_color.vmt`: makes the bar a solid block. Delete it to get the stock health cross back.
  - The budhud `_enabled` toggles are budhud's defaults, so they aren't stored here.
- `tf2/registry/tf-settings.reg`: TF2 video settings from `HKCU\Software\Valve\Source\tf\Settings` (1920x1080
  fullscreen, MSAA 4x and so on). Steam's `User Token` values are left out. The file includes the GPU's vendor and
  device IDs. On a different GPU, TF2 may redetect some video settings on first launch.
- Launch options: `-novid -nojoy -nosteamcontroller -nohltv -particles 1` (printed by the script).

### CS2 (`cs2/`)

- `cs2/game/csgo/cfg/autoexec.cfg`: knife quick-switch on MOUSE4 and jump on the mouse wheel. It ends with
  `host_writeconfig`, so the binds are also saved in the key file below.
- `cs2/userdata/730/local/cfg/`: settings from the Steam account folder (`Steam/userdata/<id>/730/`).
  - `cs2_user_convars_0_slot0.vcfg`: crosshair, sensitivity 0.42, viewmodel and buy menu.
  - `cs2_user_keys_0_slot0.vcfg`: binds.
  - `cs2_video.txt`: video settings, 1440x1080 fullscreen at 280 Hz.
  - `cs2_machine_convars.vcfg`: machine settings.
- `cs2/userdata/730/remote/`: the Steam Cloud copies of the convars and keys, plus `cs2_preferred_items.txt`
  (loadout preferences).
- Launch options: none.

### PC settings (`pc/`)

NVIDIA driver, Windows, display, monitor and Steam client settings that affect both games, plus a review of what's
worth A/B testing. See [pc/README.md](pc/README.md). Run `pc\apply-pc-settings.ps1` separately from an elevated
PowerShell, because it changes system settings. Use `-WhatIf` first to preview.

## Not included (on purpose)

- Generated or cache files: `*.sound.cache`, `user.scr`, `trustedlaunch.cfg`, `*_lastclouded`, demos, and the old
  2022 CS:GO `config.cfg`.
- The Overwolf game-state integration cfg in the CS2 folder. Overwolf creates it again when it's installed.

## Updating this backup

Copy the changed files back into the matching folder here, then commit. If you change a mod, update the table above
and `$Sources` at the top of `restore.ps1`. The pinned versions and hashes there are only the fallback.
