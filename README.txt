MOD: Intelligent AI
Author: Compartany
Version: See [version.txt]
Base: Into the Breach v1.2.24, Mod Loader v2.6.3, modApiExt v1.14
Code: https://github.com/Compartany/IntelligentAI
Link:
    [EN] http://subsetgames.com/forum/viewtopic.php?f=25&t=38195
    [CN] https://www.bilibili.com/read/cv13990559
Download:
    [github] https://github.com/Compartany/IntelligentAI/releases
    [weiyun] https://share.weiyun.com/7laJWpe3 (alternate)
My MODs:
    https://github.com/Compartany/ITB-MODs/blob/main/mod-list.md

Do you find the game too easy because enemies' AI is too low? This MOD will completely change it.

You can customize the difficulty factor or just play the [V. Hard] or [Imposs.] difficulty.

How it works:

- Probability Increased
    - Attacks on special pawns and special buildings
    - Grapple attack targets immobile pawns (e.g. ground Mech that suspends in water)
    - Grapple attack targets Ranged and Science Mechs
    - Move to edges or corners of the map
    - Move to upper part of the map
    - Move to tile between buildings
    - Flying pawns move to tile near TERRAIN_WATER or TERRAIN_HOLE
- Probability Decreased
    - Non-grapple attack targets pawns
    - The phenomenon of pawns being close to each other
    - Injuring friendly pawns
    - Move to Environment tile
    - Move to tile with dangerous item
    - Move to A.C.I.D. tile
    - Move to tile near negative score area
    - Move to tile near TERRAIN_MOUNTAIN
- Others
    - Consider tiles around the target tile when attacking (to ensure that it can still deal effective attacks after being moved if possible)
    - Consider the amount of damage when attacking buildings
    - Optimize the handling of mechanisms involving Frozen, A.C.I.D., Shield, Armor, etc.
    - Optimize Blobber targeting AI
    - Optimize Spider targeting AI

Use:
1. Extract Mod Loader to game directory (https://subsetgames.com/forum/viewtopic.php?f=26&p=117100)
2. Extract MOD to [mods] directory (The path to this file should be [%GAME_DIR%/mods/EnvManipulators/README.txt])
3. Run game
4. Enable MOD in [Configure Mods]
5. . If it does not work, please restart the game