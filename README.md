# DOOM iOS

An open-source iOS port built on [doomgeneric](https://github.com/ozkl/doomgeneric). It provides a native UIKit renderer, touch controls, and WAD importing through the Files picker.

## Game data

No copyrighted game data is included. On first launch, import a legally obtained `DOOM.WAD` or `DOOM1.WAD` file. WAD files are intentionally ignored by Git.

## Build

1. Clone with `git clone --recursive` (or run `git submodule update --init`).
2. Install Xcode 16 and XcodeGen.
3. Run `xcodegen generate`.
4. Open `DOOM-iOS.xcodeproj` and choose your signing team.
5. Build to an iPhone or iPad running iOS 15 or later.

GitHub Actions creates an **unsigned** IPA on every push. Tagged commits such as `v1.0.0` also create a GitHub Release. Install the IPA only after signing it with your own Apple development certificate or a compatible personal-signing workflow.

## Controls

- Arrow buttons: move and turn
- FIRE: fire
- USE: open/activate
- MENU: open or close the menu

## License

The combined work is licensed under GPL-2.0. doomgeneric contains code from id Software and Chocolate Doom; its notices are preserved under `Vendor/doomgeneric`.
