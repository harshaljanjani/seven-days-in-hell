<h1 align="center">Seven Days In Hell</h1>

<p align="center">
  <img width="400" height="400" alt="Seven Days In Hell" src="https://i.ibb.co/84Btch4f/Seven-Days-In-Hell.png" />
</p>
<img alt="1" src="https://github.com/user-attachments/assets/8701c424-f274-45dd-aaf0-e48a1f1f74a9" />
<img alt="2" src="https://github.com/user-attachments/assets/1d32f992-1d95-40c6-a470-34299940ca6b" />
<img alt="3" src="https://github.com/user-attachments/assets/ef2bbaf6-4ab6-44c7-b337-ca550f604040" />
<img alt="4" src="https://github.com/user-attachments/assets/86318907-e579-423c-865c-44ced8e56237" />

### About

Three years ago, Alterra Colonial Sciences deployed a lone xenogeologist to Sector 4546B-7 to investigate an ecological anomaly. His name was Dr. Elias Voss. He was a solo operative. No support team, no backup extraction, no second chances. He lasted seven days. His final transmission was severely degraded, the only fragment recovered contained four words: "seven days in hell". Every observation he made, every warning he tried to leave behind: gone. But the visor he built from salvaged sensor equipment survived. Alterra repaired the firmware but could not recover Voss's notes.

Now it is your turn.

You have been redeployed to the same sector, wearing the same visor, to face whatever killed the last person who stood where you are standing. Something deep beneath the ocean floor has fractured open, and the readings match exactly what they saw before they lost Voss. What crawled out of that fracture? What did Voss see in his final days that he could not survive? And why does the visor he built track things that Alterra's own scientists still do not fully understand?

You have seven days to find out. Or not.

### How to Install

**UE4SS Installation (if you haven't done it yet):**

1.  Go to the Subnautica 2 UE4SS releases page: [https://github.com/Subnautica2Modding/Subnautica2-UE4SS/releases/tag/1.0.0](https://github.com/Subnautica2Modding/Subnautica2-UE4SS/releases/tag/1.0.0)
2.  Download `UE4SS_v3.0.1-953-gb872ad11.zip`.
3.  Extract the zip. You should see two items: a `dwmapi.dll` file and a `ue4ss` folder.
4.  Navigate to `Subnautica2\Subnautica2\Binaries\Win64\` inside your game folder.
5.  Place both items (`dwmapi.dll` and the `ue4ss` folder) into that `Win64` folder.

The installation is straightforward and should only take a minute.

**Install the Blueprint files:**

1.  Navigate to `Subnautica2\Content\Paks\` inside your game folder.
2.  If a folder called `LogicMods` does not exist, create it.
3.  Copy the entire `ExtinctionEvent` folder from this zip's `LogicMods` directory into `LogicMods`

With the blueprints in place, you're ready for the next step.

**Install the Lua scripts:**

1.  Navigate to `Subnautica2\Binaries\Win64\ue4ss\Mods\ConsoleCommandsMod\Scripts\` inside your game folder.
2.  Copy all files from the `Scripts` folder in this zip into that directory (`Scripts\*` → `ConsoleCommandsMod\Scripts\`). This places `main.lua`, `ee_atmosphere.lua`, `ee_lore.lua`, `ee_spawn.lua`, `ee_test.lua`, and `ee_visor.lua` into the Scripts folder.
3.  **NOTE:** This replaces the default `main.lua` with one that loads the mod's modules. If you have other UE4SS mods that added their own `require()` lines to `main.lua`, open the new `main.lua` in a text editor and add your other `require()` lines back.

Once completed, the mod is fully installed.

### AI Disclosure

The project logo is AI-generated. AI assistance has been used during development, while the mod itself has been built through dedicated engineering efforts.

### Before You Play

1.  **Start a new game:** Do not load previous saves while this mod is installed. The mod initializes systems from Day 0 and is not designed to be injected into an existing world.
2.  **Single player only:** Multiplayer is not supported in this release. Co-op support is planned for a future update.
3.  **This is an early beta:** The mod has been developed and tested by an individual. Although extreme care has been taken to cover edge cases, crashes may occur. If the game crashes, relaunch and continue from your last save; progress is preserved through the game's save system.
4.  **Display scaling**: The visor HUD was built and tested at 1920×1080. Other resolutions and display configurations may produce layout differences. Widescreen and ultrawide users may see elements positioned differently than intended.
