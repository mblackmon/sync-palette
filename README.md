# sync-palette

A utility for helping standardize your colors in Interface Builder.  Sync-palette generates Color Palette file (.clr), which are used in Interface Builder and other mac apps to visually pick colors.  This allows color standardization in your files outside of code, such as Interface Builder, Acorn, Pages, and all other apps that use the standard macOS color picker (so not Sketch).

## Usage
sync-palette uses a text file containing hex colors and titles as input.  For example, the file could be like this SamplePalette.txt:
```
//Example of a color scheme
#BB8954	Dark Khaki
#7E5233	Sienna
#442E27	Dark Olive Green
```
Once specified, run sync-palette to generate a .clr file:
```
sync-palette sync-palette --in ./SamplePalette.txt --out CoolColors.clr 
```
To install the colors for your apps to use, copy the .clr file to `~/Library/Colors`.  Following the above:
```
cp ./CoolColors.clr ~/Libary/Colors/
```


Restart any open apps you want to see the new palette.  It should now appear in the color picker of your apps now.  

### Mac only
sync-palette works only on macOS.

## What are Color Palette Files?
They are the files that generate this interface:  

<img src="https://developer.apple.com/design/human-interface-guidelines/macos/images/color-panel-light_2x.png" width=300 >

You can use the pulldown (marked "Developer" in the image above) to select your custom colors.

## License
sync-palette is released under the MIT license.