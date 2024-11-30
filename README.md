---
# Important Notice!
### For this plugin to work properly, players need to have a specific configuration to enable the automatic download of custom files. 
### To achieve this, you can use the [fof-enable-custom-files](https://github.com/paralhama/fof-enable-custom-files) plugin developed by me! :)
With the plugin above, all custom file download configurations will be done automatically for the players.
### For this plugin to work correctly you must insert the following ConVars in your ```server.cfg```:
- fof_sv_currentmode 2
- mp_teamplay 1
- fof_sv_maxteams 2

### Remember that you need to use a plugin that will automatically pre-cache the resources you have placed and register them in the Download-Table. 
### I use and recommend the [S-Downloader](https://github.com/paralhama/S-Downloader) plugin for this.


---
# sm-fistful-of-zombies Paralhama version :D
I added some new features to this plugin :D
- Infecteds do not take fall damage and move faster.
- Barrels thrown by infected catch fire and explode after a short time.
- Infected are slowed down when receiving any damage that is not caused by `x_arrow`, `physics`, `prop_dynamic`, `dynamite`, `kick` or `blast`!                         
If the infected player receives damage from any of the items on this list, the player will not be slowed down, as these items already cause a slowdown.
- In the [CrimsonTautology](https://github.com/CrimsonTautology/sm-fistful-of-zombies) version,  all the whiskeys around the maps are removed and replaced with random weapons. I also added `fof_horse` and all `npc_horse`, to be replaced with weapons as well. And when all weapons are spawned on the map, a glowing outline is applied to all of them, thanks to [Backwards](https://github.com/backwards-dev)  for making it possible to enable outline glows on weapons and props on fistful of frags :)
- Infected players can still pick up some weapons, even though a function is in place to prevent this and remove the weapon from the player. This creates an issue where, when an infected player picks up a weapon, it is removed from both the player and the map, reducing weapon availability for the human team. The solution was to drop the removed weapon at the position of the infected player who picked it up.
- Replaced all small TNT barrels and some props with large TNT barrels. Now, all `prop_physics_respawnable` that contain the models `FurnitureDresser`, `wood_crate`, and `barrel1_explosive` are converted to `barrel2_explosive`.
- Commands added on `fof_zombies_config.cfg`
  - `foz_infected_damage`: Set the damage multiplier that human players deal to infected, lower values than 1.0 reduce damage (example, 0.50 means half damage). HEAD DAMAGE ON INFECTED PLAYERS IS ALWAYS 1.0, AS PER GAME STANDARD.
  - `foz_infected_slow`: Change the max speed for an infected player when receive damage.
  - `foz_infected_slow_time`: Seconds that the infected player will be slowed when taking damage.
  - `foz_infected_speed`: Change the max speed for a infected player.
- The plugin [Map Lighting Changer](https://github.com/NockyCZ/Map-Lighting-Changer) made by [Nocky](https://github.com/NockyCZ) has been unified with this plugin, and now it is also possible to turn any map into a night version, making it darker. **(Some maps, like "fof_overtop" and "fof_cripplecreek", may produce unexpected results. While it can be a tedious process, it's recommended to test each map individually and identify the ones that work best for your preferences.)**
### edit the CFG to make any map night time in `addons\sourcemod\configs\fistful_of_zombies_maps.cfg
```c++
// b - darkest
// m - normal (Default)
// z - brightest

// !!! DONT USE "a" value, because this value making surfaces completely black !!!
// The maps that are already configured below are the ones I have already tested
//and they looked good with the night mode modification
//other maps looked strange
//but feel free to insert any map in the configuration below
//but remember to test if the map looks acceptable
//as some maps look very strange

"MapLightingChanger"
{
	"fof_fistful" // Map Name
	{
		"light"		"b" // Lightning value (Use the alphabet "b" being the darkest, "z" being the brightest) 
	}
        "fof_desperados"
	{
		"light"		"z"
	}
        "fof_depot"
	{
		"light"		"m"
	}
}
```
- Nocky's plugin only darkens the maps to simulate night but doesn't remove the sun, so on some maps, the sun is still visible while the rest of the map appears darker. To fix this, I modified the skybox of every map to fof05, which is the full moon sky from Fistful of Frags. This creates a more immersive atmosphere, aligning better with the theme of the infected vs. humans game mode.
![fof_fistful](https://github.com/user-attachments/assets/7b4573bb-82ab-435f-a4c5-9882e5adbc28)
![fof_desperados](https://github.com/user-attachments/assets/1e7cd6cf-9316-414e-aa3f-d82af4f959d5)

[Build Status](https://github.com/CrimsonTautology/sm-fistful-of-zombies/workflows/Build%20plugins/badge.svg?style=flat-square)
[![GitHub stars](https://img.shields.io/github/stars/CrimsonTautology/sm-fistful-of-zombies?style=flat-square)](https://github.com/CrimsonTautology/sm-fistful-of-zombies/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/CrimsonTautology/sm-fistful-of-zombies.svg?style=flat-square&logo=github&logoColor=white)](https://github.com/CrimsonTautology/sm-fistful-of-zombies/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/CrimsonTautology/sm-fistful-of-zombies.svg?style=flat-square&logo=github&logoColor=white)](https://github.com/CrimsonTautology/sm-fistful-of-zombies/pulls)
[![GitHub All Releases](https://img.shields.io/github/downloads/CrimsonTautology/sm-fistful-of-zombies/total.svg?style=flat-square&logo=github&logoColor=white)](https://github.com/CrimsonTautology/sm-fistful-of-zombies/releases)

Fistful of Zombies; a custom zombie survival game mode for Fistful of Frags.

![image](https://github.com/user-attachments/assets/4621e29c-ce04-4643-981a-883646b5d46a)
### I would like to express my gratitude and congratulations to [Nimrod Hempel](https://steamcommunity.com/profiles/76561198153465035/) for animating the view model claws
![image](https://github.com/user-attachments/assets/f4085e93-de0f-487a-a551-8912a8cd6872)
![image](https://github.com/user-attachments/assets/ed1f07f5-53d5-4192-b143-bbd0af5ccb99)







## Requirements
* [SourceMod](https://www.sourcemod.net/) 1.10 or later
* (optional) [SteamWorks](https://forums.alliedmods.net/showthread.php?t=229556) extension (only used to change the game description in the browser).
* (optional) [MapFix Plugin](https://github.com/CrimsonTautology/sm-mapfix-fof) that fixes a few issues with Fistful of Frags.


## Installation
Make sure your server has SourceMod installed.  See [Installing SourceMod](https://wiki.alliedmods.net/Installing_SourceMod).  If you are new to managing SourceMod on a server be sure to read the '[Installing Plugins](https://wiki.alliedmods.net/Managing_your_sourcemod_installation#Installing_Plugins)' section from the official SourceMod Wiki.

Download the latest [release](https://github.com/CrimsonTautology/sm-fistful-of-zombies/releases/latest) and copy the contents of `addons` to your server's `addons` directory.  It is recommended to restart your server after installing.

To confirm the plugin is installed correctly, on your server's console type:
```
sm plugins list
```

## Usage


### Commands
NOTE: All commands can be run from the in-game chat by replacing `sm_` with `!` or `/`.  For example `sm_rtv` can be called with `!rtv`.

| Command | Accepts | Values | SM Admin Flag | Description |
| --- | --- | --- | --- | --- |
| `foz_reload` | None | None | Config | Force a reload of the configuration file |
| `foz_dump` | None | None | Root | (debug) Output information about the current game to console |

### Console Variables

| Command | Accepts | Values | Description |
| --- | --- | --- | --- |
| `foz_enabled` | boolean | 0-1 | Whether or not Fistful of Zombies is enabled |
| `foz_config` | string | file path | Location of the Fistful of Zombies configuration file |
| `foz_round_time` | integer | 0-999 | How long survivors have to survive in seconds to win a round in Fistful of Zombies |
| `foz_respawn_time` | integer | 0-999 | How long zombies have to wait before respawning in Fistful of Zombies |
| `foz_ratio` | float | 0-1 | Percentage of players that start as human. |
| `foz_infection` | float | 0-1 | Chance that a human will be infected when punched by a zombie.  Value is scaled such that more human players increase the chance |
| `foz_infected_damage` | float | 0.1-1.0 | Set the damage multiplier that human players deal to infected, lower values than 1.0 reduce damage (example, 0.50 means half damage). HEAD DAMAGE ON INFECTED PLAYERS IS ALWAYS 1.0, AS PER GAME STANDARD.! |
| `foz_infected_slow` | float | 0-320.0 | Change the max speed for an infected player when receive damage. |
| `foz_infected_slow_time` | float | 0.5-2.0 | Seconds that the infected player will be slowed when taking damage. |
| `foz_infected_speed` | float | 255.0-320.0 | Change the max speed for a infected player. |

## Mapping
The plugin is designed in such a way that it can run on any shootout map.  However due to unintended map exploits they may not be balanced for this game mode.  Some things to keep in mind if you want to build your own maps for this game mode:

* The prefix `foz_` has been adopted for maps designed for this gamemode. e.g. foz_twintowers, foz_undeadwood, foz_greenglacier
* The `item_whiskey`, `fof_horse`, `npc_horse` and all `fof_crates` entities is used for the spawn points for random weapons that appear in the map.
* From a gameplay stand point consider the vigilante team to be the human team and the desperado team as the zombie team.  Thus for player spawn points, `info_player_vigilante` are used as the spawn points for humans and `info_player_desperado` are used for the spawn points of zombies.
* If any `info_player_fof` spawn points exists, such as in Shootout maps, they will be randomly replaced with either a `info_player_vigilante` or `info_player_desperado` spawn point with equal distribution.
* `fof_buyzone` entity are removed from the map.
* If an `fof_teamplay` entity exists on the map it will be modified by the plugin to handle some gamemode events.
* If no `fof_teamplay` entity exists a default one will be added to the map.


## Compiling
If you are new to SourceMod development be sure to read the '[Compiling SourceMod Plugins](https://wiki.alliedmods.net/Compiling_SourceMod_Plugins)' page from the official SourceMod Wiki.

You will need the `spcomp` compiler from the latest stable release of SourceMod.  Download it from [here](https://www.sourcemod.net/downloads.php?branch=stable) and uncompress it to a folder.  The compiler `spcomp` is located in `addons/sourcemod/scripting/`;  you may wish to add this folder to your path.

Once you have SourceMod downloaded you can then compile using the included [Makefile](Makefile).

```sh
cd sm-fistful-of-zombies
make SPCOMP=/path/to/addons/sourcemod/scripting/spcomp
```

Other included Makefile targets that you may find useful for development:

```sh
# compile plugin with DEBUG enabled
make DEBUG=1

# pass additonal flags to spcomp
make SPFLAGS="-E -w207"

# install plugins and required files to local srcds install
make install SRCDS=/path/to/srcds

# uninstall plugins and required files from local srcds install
make uninstall SRCDS=/path/to/srcds
```


## Contributing

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


## License
[GNU General Public License v3.0](https://choosealicense.com/licenses/gpl-3.0/)


## Acknowledgements

* Resi - Developed the custom map "foz_undeadwood"
* elise - Developed the custom map "foz_twintowers"
* nbreech - Developed the custom map "foz_greenglacier"
