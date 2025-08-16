# Apply Click-Through

I have actually found **a robust solution that solves this issue** on the latest version of *MacOS* as of now (`15.6`). It will essentially **enable click-through** with no noticeable effects to the user.

1. `brew install hammerspoon`
    - If you are not using [Homebrew][2], simply install [Hammerspoon][3] from their website.
2. Launch `hammerspoon`
2. Configure `hammerspoon` such that it has sufficient rights.
3. Click on the **hammer** icon in the top-right menu bar and select **Open Config.**
    - This config is located at `/Users/$USER/.hammerspoon/init.lua` for me.
4. Copy the [following config][1] into your `hammerspoon` config.
5. Click on the **hammer** icon again and press **Reload Config**.
6. `tail -f /Users/$USER/hammerspoon_clickthrough.log`
    - This will print the logs of click events to help verify whether the solution is working.

So far I have not been able to find an application that does not work with this. I would also like to mention:

 - I will **continuously update this reply and the config link if I face any issues or find improvements**. I hope to someday bundle this into a simple install script if it proves to really cause no issues in the long run.
 - If **YOU** face any issues or know improvements to make this even better, please let me know!
 - Note that if an application does behave strangely with this script, you can exclude it from the behaviour via tweaking the config a bit.

  [1]: https://gist.github.com/dainank/fd236aa71a8b3fcf637b9d8428ce98db
  [2]: https://brew.sh/
  [3]: https://www.hammerspoon.org/