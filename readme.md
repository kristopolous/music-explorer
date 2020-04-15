A set of tools for exploring archiving music surrounding the following:

 * youtube-dl
 * mpv

There's also a way to navigate and control that uses tmux, notion, and a usb foot pedal, really. You should have id3v2 and amixer if you want to do that one.

Eventually this intends to be rewritten using SQLite and url references instead of downloading the assets (as currently happen).

The system is currently based around bandcamp ... downloading entire labels from bandcamp. I know what you're saying "that sounds shady." --- I've actually spent 300% more buying music on bandcamp month over month than I did before because this tool exposes artists to me for me to buy.

The abstractions are like any powerful sets of tools: your personal moral compass is the guide to how you use it.

I have a number of other tools that are not being included in this system yet.  Let's go over it.

## Getting music

As I said this is label based. The first thing to do is run install in some resolvable path. (`$HOME/bin` is the default)

    $ ./install.sh

Ok, that was easy. Now figure out where you want the music to go. Currently I recommend some large partition, like say a 512G SD card if you're on a laptop or a RAID array. For me I'm going to use `/sd/mp3/label`

    $ mkdir -p /sd/mp3/label
    $ cd /sd/mp3/label

Now let's say you want to get a label or artist, heck let's use me, pay me nothing, it's cool. (install youtube-dl, it's in apt, beofre you do this)

    $ album-get chrismckenzie
    ♫ chrismckenzie ♫
    --- /sd/mp3/label/chrismckenzie/astrophilosophy
      ⇩ https://chrismckenzie.bandcamp.com/album/astrophilosophy
    ...
    $

woah shit, what just happened? Y

    $ tree chrismckenzie
    chrismckenzie
    ├── astrophilosophy
    │   ├── chris mckenzie - Astrophilosophy-3196176877.mp3
    │   ├── chris mckenzie - Instrumentals-2161707097.mp3
    │   ├── chris mckenzie - Vocals-589691184.mp3
    │   └── exit-code
    └── textures-i
        ├── chris mckenzie - 6AM-3099860585.mp3
        ├── chris mckenzie - Dawn Break-3496240403.mp3
        ├── chris mckenzie - Drunken Princess-1900005411.mp3
        ├── chris mckenzie - Homage to Vangelis-515942329.mp3
        ├── chris mckenzie - October Wind-2524682866.mp3
        ├── chris mckenzie - Rose-2272020348.mp3
        ├── chris mckenzie - Space Royalty-3306453676.mp3
        └── exit-code

That's all my stuff along with youtube-dl's exit codes that get checked for errors.

#### But wait, there's more!

So let's say you want to see if I added anything

    $ album-get chrismckenzie
    ♫ chrismckenzie ♫
    $

Nope, it's smart. Sees there's nothing new.  Alright, now let's say you do this for a bunch of other labels and artists. Let's add a second one, oh I dunno, say cpurecords.

CPU records uses its own custom domain, https://shop.cpurecords.net/ but it is in fact, just a bandcamp site. So the syntax is a little different, we specify the url, followed by the name

    $ album-get shop.cpurecords.net cpurecords
    ♫ cpurecords ♫
    ... chug chug chug ...
    $

Now you can see a file `cpurecords/domain` which has the real domain. This is important for the next part.

#### Mass updating

So you go along and you have say 20 labels you follow and a week passes and you want to see what's new.  We use our trusty command again:

    $ album-get
    ♫ chrismckenzie ♫
    ♫ cpurecords ♫
    ... chug chug chug ...
    $

It will check all the entries for new things. This is like "following" and having a "feed" albiet a rather cobbled together inefficient version.

## Playing music

Now you have all of this stuff to go through you *could just do it in a disorganized manner* maybe loading it into some gui tool and then trying to sort through it. 

**No! We are better than that**

Instead what we are going to do is play each release ONCE, then we decide what to do with it. The ones you like, feel free to do what is right and go and buy things, I do.

Here's how we do it

    $ mpv-once

    https://chrismckenzie.bandcamp.com/album/astrophilosophy

    Playing: chrismckenzie/astrophilosophy/chris mckenzie - Astrophilosophy-3196176877.mp3
    .. listen

    Exiting... (Quit)
    chrismckenzie/astrophilosophy >> 


 Alright now we can decide what to do with it. We can

  * r - replay it
  * pu - purge (move it /tmp and mark it as undesired)
  * s - skip the decision making
  * 1-5 - rate it from 1-5

I'm going to decide to dump my own music, that slouch is awful.

    chrismckenzie/textures-i >> pu
    + base=/sd/mp3/label
    + mkdir -p /tmp/chrismckenzie/astrophilosophy
    + mv '/sd/mp3/label/chrismckenzie/astrophilosophy/chris mckenzie - Astrophilosophy-3196176877.mp3' '/sd/mp3/label/chrismckenzie/astrophilosophy/chris mckenzie - Instrumentals-2161707097.mp3' '/sd/mp3/label/chrismckenzie/astrophilosophy/chris mckenzie - Vocals-589691184.mp3' /sd/mp3/label/chrismckenzie/astrophilosophy/exit-code /tmp/chrismckenzie/astrophilosophy
    + touch /sd/mp3/label/chrismckenzie/astrophilosophy/no

And there we go. A placeholder file is put there so that when album-get comes through again, it won't try to grab it again.


... there's a lot more ... I'll write later
