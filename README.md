# Apple Click-Through

> [!CAUTION]
> This script is WIP. There may be unforeseen issues.

This script **enables click through on macOS**, allowing you to **click UI elements inside inactive windows without clicking the window first**.

> [!NOTE]
> Tested and working on MacOS 27 & 28. Prior versions may be compatible.

----

## Setup
> Can be done without cloning repo if desired.

1. `brew install hammerspoon`
    - If you are not using [Homebrew][2], simply install [Hammerspoon][3] from their website.
2. Launch `hammerspoon`.
2. Configure `hammerspoon` such that it has sufficient rights.
3. Click on the **hammer** icon in the top-right menu bar and select **Open Config**.
    - This config is located at `/Users/$USER/.hammerspoon/init.lua` for me.
4. Copy the [following config][1] into your `hammerspoon` config.
    - Run `[./install.sh](./install.sh)` from the repository root to do this effortlessly.
5. Click on the **hammer** icon again and press **Reload Config**.
6. `tail -f ~/Library/Logs/apple-click-through/main.log`
    - This prints click event logs to verify the solution and debug unexpected behavior.

----

## Update
> Repeat steps 4/5 from above.

Copy the latest version of the [Lua Script](https://github.com/dainank/apple-click-through/blob/main/init.lua) to your `/Users/$USER/.hammerspoon/init.lua` location.

> [!TIP]
> The above requires quite some manual work, it is easier to clone the repository. For updates, you can then just run `git pull && ./install.sh --force` to get latest changes. Feel free to automate this one-liner every month or so for automatic latest greatest.

----

## To Note

- I hope to someday bundle this into a simple install script if it proves stable over time.
- If you encounter any issues or have improvements in mind, please let me know via the [issues tab](https://github.com/dainank/apple-click-through/issues)! Include a relevant log snippet (see step 6 above for info).
- For any applications that misbehave with this script, you can exclude them by tweaking the config.

  [1]: https://github.com/dainank/apple-click-through/blob/94e243720499a8df8595485508d5c6b1802269a2/init.lua
  [2]: https://brew.sh/
  [3]: https://www.hammerspoon.org/

----

## History

The original [GitHub Gist for this idea, can be found here](https://gist.github.com/dainank/fd236aa71a8b3fcf637b9d8428ce98db), which was sparked by this discussion [here](https://apple.stackexchange.com/q/269622/583325).

----

## Mirror

We have a mirror on _gidot_, an open-source alternative to _GitHub_: https://gitdot.io/dainank/apple-click-through

----

## Special Thanks
> ... to all the people submitting issues and testing this script!

- [@ojde](https://github.com/ojde)
- [@autoclave73](https://github.com/autoclave73)
