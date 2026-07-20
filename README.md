# Apple Click-Through

> [!CAUTION]
> This script is WIP. There may be unforeseen issues.

The goal of this script is to provide **a robust solution on MacOS for not requiring an explicit click to make window active, before UI elements inside can be clicked**. It will essentially **enable click-through** with no noticeable effects to the user.

> [!INFO]
> This script has been tested and works on MacOS 27 & 28.

----

## Setup

1. `brew install hammerspoon`
    - If you are not using [Homebrew][2], simply install [Hammerspoon][3] from their website.
2. Launch `hammerspoon`
2. Configure `hammerspoon` such that it has sufficient rights.
3. Click on the **hammer** icon in the top-right menu bar and select **Open Config.**
    - This config is located at `/Users/$USER/.hammerspoon/init.lua` for me.
4. Copy the [following config][1] into your `hammerspoon` config.
5. Click on the **hammer** icon again and press **Reload Config**.
6. `tail -f ~/Library/Logs/apple-click-through/main.log`
    - This will print the logs of click events to help verify whether the solution is working (also use these logs to debug if behavior is as expected).

## To Note

 - I hope to someday bundle this into a simple install script if it proves to really cause no issues in the long run.
 - If **YOU** face any issues or know improvements to make this even better, please let me know [via the issues tab](https://github.com/dainank/apple-click-through/issues)! Please provide a subset of the log from step 6 above.
 - For any applications that are misbehaving with this script, you can exclude it by tweaking the config a bit.

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
