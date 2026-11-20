# PC settings that affect TF2 and CS2

These settings were read from this PC on 2026-11-20. The PC is a Ryzen 7 5800X3D with an RTX 3080 Ti on driver
617.14, running Windows 11. The gaming monitor is an ASUS VG259QM (280 Hz, G-SYNC Compatible), with a Dell S3220DGF
as a second screen. The raw readings are in [`windows/snapshot-2026-11-20.json`](windows/snapshot-2026-11-20.json) and
[`nvidia/drs-snapshot.json`](nvidia/drs-snapshot.json).

To re-apply them, run this from an elevated PowerShell. Use `-WhatIf` first to preview:

```powershell
powershell -ExecutionPolicy Bypass -File .\pc\apply-pc-settings.ps1 -ProfileInspector "C:\path\to\nvidiaProfileInspector.exe"
```

The script sets the power plan, mouse, Game Mode and HAGS. It also imports the NVIDIA settings when you pass
`-ProfileInspector`. Everything in the **Manual** sections below has to be set by hand.

## NVIDIA driver (global profile)

All of these are in the driver's global/Base profile. CS2 and TF2 have no custom per-game settings, so both games
inherit these values. [`nvidia/global-base-profile.nip`](nvidia/global-base-profile.nip) holds exactly these 11
values. Import it with [NVIDIA Profile Inspector](https://github.com/Orbmu2k/nvidiaProfileInspector/releases), either
with `-silentImport` or through Import in the app. The import replaces the global profile, so any other global
changes are reset to driver defaults.

| NVIDIA Control Panel setting | Value | Driver default |
|---|---|---|
| Vertical sync | **On** (forced) | Use the 3D application setting |
| Low Latency Mode | **On** (max pre-rendered frames 1) | Off |
| Monitor Technology / G-SYNC | **G-SYNC Compatible, full screen and windowed mode** | full screen only |
| Power management mode | **Prefer maximum performance** | Normal |
| Threaded optimization | **On** | Auto |
| Preferred refresh rate | **Highest available** | Application-controlled |
| Shader cache size | **10 GB** | Driver default |
| Vertical sync tear control | Standard (same as default) | Standard |
| Max frame rate | Off | Off |
| Texture filtering - Quality | Quality (default) | Quality |

### Manual (NVIDIA Control Panel)

- **Set up G-SYNC**: tick "Enable G-SYNC, G-SYNC Compatible" for **full screen and windowed mode**, and tick "Enable
  settings for the selected display model" for the VG259QM.
- **Adjust desktop size and position** (VG259QM): Scaling mode **Full-screen**, and tick **Override the scaling mode
  set by games and programs**. This is what stretches CS2's 1440x1080 (4:3) across the screen. In the active display
  layout, Windows has the VG259QM path set to *stretched*. NVIDIA's "Perform scaling on: GPU / Display" choice is
  stored in an undocumented driver blob, so check it in the control panel.
- **Change resolution**: VG259QM 1920x1080 at **279.857 Hz**, Dell at 2560x1440 at **164 Hz**. Both default to 60 Hz on
  a fresh install.

## Windows

| Setting | Value | Applied by script |
|---|---|---|
| Power plan | **High performance** (CPU min/max 100 %, PCIe power saving off) | yes |
| Hardware-accelerated GPU scheduling | **On** | yes (admin, then reboot) |
| Game Mode | **On** | yes |
| Mouse "Enhance pointer precision" | **Off**, pointer speed 10/20 | yes |
| Fullscreen optimizations | Windows default, no compatibility flags on the game exes | (default) |
| Windows "Optimizations for windowed games" / VRR toggle | Windows default | (default) |
| Xbox Game Bar background recording | Off | (default) |
| Memory Integrity (Core isolation) | **On**, kept on deliberately | not touched |
| HDR | Off on both monitors | manual |

### Manual (Windows display layout)

When not gaming, the VG259QM is a **portrait** secondary screen and the Dell is the main display. Before playing,
rotate the VG259QM to landscape: pivot it physically, then set Display orientation to Landscape in Settings > System >
Display. CS2 is saved with `monitor_index 0`, so it opens on that monitor.

## Monitor (VG259QM on-screen menu)

These can't be read from Windows. They were recorded earlier and need checking by hand: **Adaptive-Sync on**, **ELMB
Sync on**. Note the OverDrive/Trace Free level and the GamePlus/crosshair settings here once you check them.

## Steam client

- Settings > Game Recording: **Record in background** (all games, default bitrate). TF2 relies on this.
- In-game overlay: on.
- Launch options are in the main README.

## CS2 in-game video settings (summary)

These are stored in `cs2/userdata/730/local/cfg/cs2_video.txt`, and restore.ps1 brings them back.

- **Resolution and display**:
  - 1440x1080, aspect ratio 4:3, exclusive fullscreen at 279.857 Hz.
  - V-Sync off in game (the driver forces it on, which is what G-SYNC needs).
- **Latency**:
  - NVIDIA Reflex **On + Boost** (`r_low_latency 2`).
  - `fps_max 280.29`.
- **Quality**:
  - Boost player contrast on.
  - MSAA 2x, CMAA off, anisotropic 16x.
  - Shader, texture, particle and shadow quality Low; dynamic shadows All.
  - Ambient occlusion off, HDR Performance, FSR off.

---

## Review (2026-11-20): what looks right, and what's worth A/B testing

Nothing here was changed. These points come from reading the settings, not from measurements.

**Set up correctly for 280 Hz G-SYNC:**

- **G-SYNC chain**: G-SYNC on, V-Sync forced on in the driver, V-Sync off in game, Reflex on. This is the standard
  low-latency, tear-free combination. With all of these on, Reflex caps CS2 a little under the refresh rate,
  at about 259 fps on 280 Hz. That's the same ~259 cap you see in TF2. The driver's Low Latency Mode setting is
  ignored in games with Reflex, so it does no harm.
- **Preferred refresh rate "Highest available"**: CS2 is saved at 279.857 Hz, the panel's real maximum.
- **CS2 visibility settings**: Boost player contrast, dynamic shadows on All, FSR off and anisotropic 16x are all
  good for seeing players clearly. Turning the rest down mostly cuts CPU and GPU load. CS2 is CPU-bound on a 5800X3D.
- **Windows**:
  - HAGS on, Game Mode on, mouse acceleration off.
  - No compatibility flags on the game exes.
  - RAM running its XMP speed (3200 MT/s). The X3D cache makes faster RAM matter little.

**Worth checking or A/B testing (ordered by likely impact):**

1. **Steam background recording runs in every game.** It keeps the NVENC encoder busy the whole time you play.
   NVENC is cheap on a 3080 Ti, but reports vary from no difference to noticeable frame-time spikes. CS2 has its own
   demos, so try turning recording off for CS2 only (Steam's per-game recording setting) and compare the frame-time
   graph (`cl_hud_telemetry_frametime_show` is already on). Keep it on for TF2.
2. **CS2 `fps_max 280.29` is above the refresh rate.** With Reflex on, Reflex's own cap of ~259 wins, so this is
   harmless today. If Reflex ever gets turned off, CS2 would hit the forced V-Sync and add latency. Setting
   `fps_max 0` and letting Reflex cap is cleaner. A fixed cap of about `fps_max 255` also works. In a match, check
   that the fps counter sits around 259.
3. **"Prefer maximum performance" is global.** It keeps the GPU at high clocks on the desktop and in every app, which
   means more heat and power use for no gain in CS2. Reflex Boost already holds the clocks up in game. An alternative
   is *Normal* globally, with *Prefer maximum performance* only in the CS2 and TF2 profiles. That's a judgment call,
   not a fix.
4. **MSAA 2x versus 4x.** If you want the best image, 4x MSAA at 1440x1080 is usually affordable on a 3080 Ti. Test
   whether 1 % lows drop (CS2 is mostly CPU-limited here).
5. **ELMB Sync with G-SYNC.** Strobing during VRR gives clearer motion but a darker image, and on many panels it
   causes strobe crosstalk (double images) in parts of the screen. A/B test it against ELMB off with a medium OverDrive
   level and pick by eye.
6. **Power plan.** High performance is fine. AMD's guidance for the 5800X3D is Windows *Balanced*, and the difference
   in games is small. USB selective suspend is enabled, which normally doesn't affect an active mouse. If you ever see
   mouse or headset dropouts, disable it.
7. **Overlays.** Discord and the NVIDIA App overlay are running. If you see hitching in CS2, try disabling their in-game
   overlays (the NVIDIA overlay's Instant Replay was off when last checked).
8. **`snd_mixahead 0.001` in CS2** is set very low. If you hear crackling or popping, this is the first thing to
   raise (back towards 0.025).
9. **Memory Integrity** costs a little performance in some games. It stays on deliberately, so this is listed for
   completeness only.

How to A/B test: change one thing at a time. Play the same map in a practice server for a few minutes with
`cl_hud_telemetry_frametime_show 1`, then compare average fps, 1 % lows and frame-time spikes. For TF2, use the
tf2-bench harness on the current PC (`C:\Users\Chris\tf2-bench`, not part of this repo).
