# LuLu
LuLu is the free open-source macOS firewall that aims to block unauthorized (outgoing) network traffic, unless explicitly approved by the user:
<p align="center"><img src="https://objective-see.com/images/LL/lulu.png"></p>

Full details and usage instructions can be found [here](https://objective-see.com/products/lulu.html). 

**To Build**<br>
LuLu should build cleanly in Xcode (though you will have remove code signing constrains, or replace with you own Apple developer/kernel code signing certificate).

**To Install**<br>
For now, LuLu must be installed via the command-line. Build LuLu (or download the pre-built binaries), then execute the configuration script (`configure.sh`) with the `-instal`l flag, as root:
```
//install
$ sudo configure.sh -install
```
&#x26A0;&nbsp; please note:
```
LuLu is currently in alpha. 

This means it is currently under active development and still contains known bugs. 
As such, installing it on any production systems is not recommended at this time! 

Also, as with any security tool, proactive attempts to specifically bypass LuLu's protections will likely succeed. 
By design, LuLu (currently) implements only limited 'self-defense' mechanisms.
```

&#x2764;&nbsp; Love this product or want to support it? Check out my [patreon page](https://www.patreon.com/objective_see) :)

**Mahalo!**<br>
This product is supported by the following patrons:
+ Lance Gaines
+ Ash Morgan
+ Khalil Sehnaoui
+ Nando Mendonca
+ Bill Smartt
+ Martin OConnell
+ David Sulpy
+ Shain Singh
+ Chad Collins
+ Harry Hoffman
+ Keelian Wardle
+ Christopher Giffard
+ Conrad Rushing
+ soreq
+ Stuart Ashenbrenner
+ trifero
+ Peter Sinclair
+ Ming
+ Gamer Bot
