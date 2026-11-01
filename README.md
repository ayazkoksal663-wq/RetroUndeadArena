# Retro Undead Arena — Godot project

A starter Godot 4 project for a retro low-poly FPS. It includes a single-player arena, a blocky first-person gun/hand, mouse look, mobile touch controls, waves of zombies and gunner enemies, and a 20-point health meter.

## Open it
1. Install Godot 4.7.2 (the project targets Godot 4.x).
2. Extract the ZIP.
3. In Godot Project Manager choose **Import** and select `project.godot`.
4. Press **F6/F5** to run.

## Mobile controls
- Left thumb area: virtual joystick for movement.
- Drag the right side of the screen: look up/down/left/right.
- Yellow FIRE circle: shoot.
- The UI adapts to the current viewport.

## Important prototype notes
- Multiplayer now includes ENet host/join logic for up to 8 players, join-code validation, retry cleanup, connection failure messages, and a 12-second timeout. Direct internet hosting still requires UDP 24567 port forwarding; mobile carrier NAT/CGNAT may require a relay server.
- Enemies use procedural low-poly models. Gunners spawn less often than zombies; shots show a bright tracer and use raycast hit detection.
- For Android, use **Project > Export** and install the Android export templates/SDK in Godot. Then add an Android preset and export an APK.
- This is a source project, not a prebuilt APK.


## Latest gameplay additions
- Improved HUD panel shows health, kills, wave, and the current weapon.
- Tap **SWITCH GUN** on mobile or press **Q** / mouse-wheel-up on desktop to cycle through Pistol, Assault Rifle, Shotgun, and Sniper.
- Each weapon has its own firing cadence, damage, range, recoil feel, tracer color, and a distinct pitch/volume treatment for the gunshot sound.
- Every projectile is visible: rifle rounds are fast green tracers, shotgun pellets are orange, sniper rounds are cyan, and pistol rounds are yellow.
- Floating damage numbers appear above enemies when shots land.
- A large armored Boss Zombie with glowing eyes, 45 HP, and stronger melee attacks appears on waves 5, 10, 15, and so on.
- Mobile firing supports holding the FIRE area for repeated shots. The switch button sits just above the fire control.


## Survival update
- Endless wave progression: each wave increases the kill target and spawn pressure. There is intentionally **no victory screen**.
- New enemy types: Runner (fast), Tank (slow and durable), Exploder (detonates at close range), and Spitter (launches green acid projectiles). Boss zombies still appear on waves divisible by five.
- Three selectable map themes in Settings: Ruined City, Military Yard, and Dark Forest. The selected map applies when you start the next run.
- Hit markers, colored muzzle flashes, and screen shake provide combat feedback.
- Press the on-screen **PAUSE** button or Escape to pause. From the pause menu you can resume, adjust settings, or return to the main menu at any time.
- Settings include look sensitivity and map selection. On mobile, drag the right side to look; sensitivity applies to touch look as well as mouse look.

## Controls
- Desktop: WASD to move, mouse to look, left click to fire, Q / mouse wheel up to switch weapons, Escape to pause.
- Mobile: left thumb area to move, drag right side to look, FIRE area to shoot, SWITCH GUN to cycle weapons, PAUSE to open the pause menu.

This source ZIP has been checked for archive integrity. Godot 4.7.2 is not installed in the build environment, so import and run it in Godot to complete runtime validation.

## Abomination & Arsenal update
- A boss spawns on waves 10, 20, 30, and every tenth wave after that, with the warning `WARNING: THE ABOMINATION APPROACHES`.
- The Abomination has 1000 HP, a visible health readout, a ground-slam shockwave, and a burst of fire projectiles.
- Defeating the boss unlocks a fireball ability. Use **F** on desktop or the **FIREBALL** button on mobile; it has a 15-second cooldown.
- Added **RPG** and **MINIGUN** to the weapon cycle. The RPG has explosive splash damage; the minigun fires rapidly. Existing infinite ammo is unchanged.
- Existing random map selection, no-settings menu, pause menu, mobile controls, and removed shootable explosive barrels are preserved.


## Bosses and special waves
- Electric Brute mini-boss: 100 HP, appears on waves 5, 15, 25, and so on. Its electric shock pulse deals only 1 damage and has a cooldown. Defeating it unlocks the Electric Rifle once per run.
- The Abomination: 1000 HP, appears on waves 10, 20, 30, and so on. Defeating it unlocks the Fireball ability once per run.
- Special events can trigger on eligible waves: Zombie Rush, Toxic Outbreak, and Blackout.
- Boss rewards are unlocks, not collectible drops; unlocked rewards do not get awarded repeatedly during the same run.


## Added mini-bosses and rare Gunner weapon

- The Charger and Screamer can appear randomly from wave 3 onward, only on non-major-boss waves.
- The Charger periodically rushes the player; its rush is announced.
- The Screamer periodically calls up to two normal zombies, respecting the existing enemy cap.
- Major bosses enter an enrage phase at 30% health, with a red aura, warning, faster movement, and faster attacks.
- Defeating a Gunner has a 5% chance to permanently unlock the Gunner's Gun. The unlock is saved in `user://retro_undead_unlocks.cfg`, is loaded in future runs, and cannot be awarded a second time.
- Existing weapons, infinite ammo, mobile controls, and the major-boss wave schedule remain in place. The Toxic Tank mini-boss is not included.


## Player profile and full reset
- First launch asks the player to create a username (1–20 characters); the name is saved locally and shown on the main menu.
- The main menu includes **CHANGE USERNAME** and a top-right **RESET PROGRESS** button.
- Reset requires confirmation and clears the username, permanent weapon unlocks, Fireball unlock, achievements/titles, high scores, and saved run; afterward, the game asks for a new username.
- Electric Rifle, Fireball, and Gunner's Gun unlocks are saved separately from the current run, so they persist across new runs and app restarts until a full reset.
- Validation note: the ZIP archive integrity is checked, but Godot is not installed in this environment, so the project has not been imported or run in the Godot editor here.

## Pixel-art texture pass

The visual texture pass uses compact 64x64 palette-limited textures with nearest-neighbor filtering for a crisp retro look. It includes pixel-art gun wood, metal and polymer maps, plus ground, concrete, rust, foliage, zombie skin, zombie cloth and metal-detail tiles. Arena props and enemy materials use the new tiles with color tinting to preserve map and enemy readability. This update changes visual assets/material setup only; gameplay logic is unchanged.


## Toxic Tank schedule update
- The Toxic Tank now spawns every 15 waves: waves 15, 30, 45, and so on. It takes priority over the normal boss schedule on those waves.
- Toxic Tank maximum health is 1,150 HP, and the boss HUD displays the matching value.
- Its enraged phase begins at 30% health.
- Note: this update changes the Toxic Tank scheduling and health in the existing procedural 3D project; it does not add a separate pixel-art sprite sheet.


## Toxic Tank update

- Toxic Tank has a dedicated procedural model: oversized arms, hunched armor, glowing eyes, and three glowing chemical tanks. It no longer uses the standard boss body silhouette.
- Toxic Tank has 1,150 HP and appears every 15 waves (15, 30, 45, ...).
- Its ranged attack spits a glowing acid projectile at the player; it alternates this with its existing ground-slam attack.
- Defeating it unlocks the Acid Gun according to the existing unlock flow.

The project should be imported and tested in Godot 4 before exporting an Android build.


## Multiplayer (Godot 4)

The main menu has **MULTIPLAYER - HOST** and **MULTIPLAYER - JOIN**. Hosting lets you select Normal or Sandbox. The displayed room code is an IPv4 address plus UDP port, for example `192.168.1.20:24567`. Enter that exact code on the joining device. The host supports up to 7 connected clients (8 players including the host). Player avatars and usernames are synchronized; the host is authoritative for enemy spawning, enemy movement/health, damage requests, and Sandbox spawn/clear requests.

### LAN

1. Put all devices on the same Wi-Fi/LAN.
2. On the host, choose **MULTIPLAYER - HOST**, select Normal or Sandbox, and keep the detected LAN IP.
3. Share the displayed `IP:24567` code.
4. On each other device, choose **MULTIPLAYER - JOIN** and enter the code.

### Internet

This project uses direct ENet/UDP connections and does not include a cloud lobby or relay service. For internet play, the host must enter their **public IPv4 address** in the Host dialog, allow the game through their firewall, and forward **UDP port 24567** on the router to the host device. Share the resulting `public-IP:24567` code. Some networks (including carrier-grade NAT and some mobile networks) do not allow inbound port forwarding; those networks require a relay or dedicated server not included in this project.

The room code is an address code, not a short random code. A short code would require a public matchmaking directory/relay service to map codes to hosts.

## Android multiplayer Error 20 diagnostic patch

The host function now closes a previous multiplayer peer before retrying, logs the Godot error string, and displays a more useful failure message instead of only saying the port may be busy.

If Android still reports Godot error 20 (`ERR_CANT_CREATE`), this patch cannot itself grant Android permissions or make a socket available. Open the project in the matching Godot 4.x editor, configure an Android export preset, and ensure the **Internet** permission is enabled in the Android export options before exporting a new APK. Then test hosting again.

For LAN testing, both phones must be on the same Wi-Fi. For internet hosting, direct ENet requires inbound UDP 24567 to reach the host; many mobile carriers use CGNAT and cannot accept inbound connections. A relay/dedicated server is needed on those networks. This patch does not add a relay service.



## Multiplayer join troubleshooting patch
- Open the host game first, choose Normal or Sandbox, then share the host's LAN IPv4 address plus `:24567` for LAN.
- On the joining phone, use the host phone's private Wi-Fi address (for example `192.168.1.20:24567`), not `127.0.0.1`.
- Both Android exports must have the Internet permission enabled in the Android export preset.
- For internet play, a public IP entered into the room code is not sufficient by itself: the host router must forward **UDP** port `24567` to the host phone, and the ISP must allow inbound traffic. Carrier data connections often use CGNAT and cannot accept direct incoming connections; use a relay/dedicated server in that case.
- The room code parser accepts `host:port` or just `host` (default port 24567), and `udp://host:port`. IPv6 literals are not supported by this room-code field.
- This patch has not been runtime-tested in Godot in this environment. Build a fresh APK from this source and test two phones on the same Wi-Fi first.


## FRIEND Easter egg
- On the first-name / change-name screen, entering `FRIEND`, `DEVICE_FRIEND`, or `PNG.FRIEND` (case-insensitive) triggers a short glitch, plays the supplied secret video, then glitches back to the name-entry screen.
- The secret trigger is not saved as the player's username. After the video, the name field is cleared so the player can enter a normal username.
- The supplied MP4 has been converted to Ogg Theora (`video/friend_easter_egg.ogv`) for Godot's built-in VideoStreamPlayer.
- Import and test on the target Android device in Godot 4.7.2 before exporting the APK; video decoding support can vary by platform/export setup.
