CopyCopyPastePaste
========

How does it work?
----

Try this:

* Select `hello`, hit CTRL+C

* Select `yeah`, hit CTRL+C

* Do CTRL+V: as usual you'll get "yeah" pasted

* **Do CTRL+<: you'll get the previous text in clipboard pasted, i.e. "hello"!**

That's it, now you have 2 copy/paste buffers!


Download the exe
----

Here is [copycopypastepaste.exe](https://github.com/josephernest/copycopypastepaste/raw/master/copycopypastepaste.exe), the 23 KB portable executable.


Why another clipboard manager?
----

There are already lots of great clipboard managers. But when trying the open-source software Ditto (15 MB package, 39 MB uncompressed, 179 MB source code package, oops!), I wanted to do a more minimalist tool that does just one single task.


How to compile
----
After having installed [FreeBasic](https://www.freebasic.net/) ([install package](https://sourceforge.net/projects/fbc/files/Binaries%20-%20Windows/FreeBASIC-1.05.0-win32.exe/download), 11 MB), you can compile with:

    "C:\Program Files (x86)\FreeBASIC\fbc.exe" copycopypastepaste.bas -s gui copycopypastepaste.rc

New features?
----

This tool is intended to be minimalist and no new features would be added soon. As the code is very simple and MIT licensed, feel free to fork it and add new features.

About
----

Code: Mysoft64 (mysoft64bits@gmail.com)

Idea / UX: Joseph Ernest ([@JosephErnest](https://twitter.com/JosephErnest))

License
----
MIT license
