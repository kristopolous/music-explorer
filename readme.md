# Music-Explorer

A set of tools for exploring music surrounding youtube-dl and mpv.

There's also a way to navigate and control the music that uses tmux, notion, and a usb foot pedal, really. You should have id3v2 and amixer if you want to do that one.

Additionally there's music-discovery navigation tools that involve discogs, search engine apis, youtube, and bandcamp. That one is done in python and has a web-interface (the code isn't here yet). Hopefully I'll get it cleaned up and presentable.

Eventually this intends to be rewritten using a SQLite backend (instead of the file system as a DB which is the current approach) and url references instead of downloading the assets (as currently happen). 

The system that is installable from this repo is currently based around only bandcamp and has no discovery systems, only a browsing one.

It works by ... downloading entire labels from bandcamp. I know what you're saying "that sounds shady." --- I've actually spent 300% more buying music on bandcamp month over month than I did before because this tool exposes artists to me for me to buy.

The abstractions are like any powerful sets of tools: your personal moral compass is the guide to how you use it.

Let's go over what's currently included:

## Getting music

This tool is label/artist based - you'll need an *unknown number* of gigabytes of disk space free (depending on your apetite) - set aside 250GB or so, disks are cheap, under $20/TB, stop raising your eyebrows at me.

The first thing to do is run `./install.sh` using a resolvable path as the arg. (`$HOME/bin` is the default)

    $ ./install.sh

Ok, that was easy. Now figure out where you want the music to go. I'm going to use `/sd/mp3/label`

    $ mkdir -p /sd/mp3/label
    $ cd /sd/mp3/label

Let's say you want to get a label or artist, heck let's use me, pay me nothing, it's cool. (install youtube-dl, it's in apt, before you do this)

    $ album-get chrismckenzie
    ♫ chrismckenzie ♫
    --- /sd/mp3/label/chrismckenzie/astrophilosophy
      ⇩ https://chrismckenzie.bandcamp.com/album/astrophilosophy
    ...
    $

Woah shit, what just happened? 

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

That's all my stuff along with `youtube-dl`'s exit codes that get checked for errors.

#### But wait, there's more!

So let's say you want to see if I added anything, just run it again.

    $ album-get chrismckenzie
    ♫ chrismckenzie ♫
    $

It's oh so clever and sees there's nothing new.  

Alright, now let's say you do this for a bunch of other labels and artists. Let's add a second one, oh I dunno, say cpurecords.

CPU records uses its own custom domain, https://shop.cpurecords.net/ but it is in fact, just a bandcamp site. 

To get it we will use the same tool. It's once again, pretty smart.

The syntax however is a little different: we specify the url, followed by the name:

    $ album-get shop.cpurecords.net cpurecords
    ♫ cpurecords ♫
    ... chug chug chug ...
    $

Now you can see a file `cpurecords/domain` which has the real domain. This is important for the next part.

#### Mass updating

So you go along and have say 20 labels you're browsing through, making it rain on a bunch of amateur musicians, and a week passes. You want to see what's new.  We use our clever command, in the directory, but this time with no arguments.  It will try to pull new stuff from everyone.

    $ album-get
    ♫ chrismckenzie ♫
    ♫ cpurecords ♫
    ... chug chug chug ...
    $

This is effectively equivalent to the social media concept of "following" and "feed" albiet a rather cobbled together inefficient orchestration.

## Playing music

Now you have all of this stuff to go through you *could just do it in a disorganized manner* maybe loading it into some gui tool and then trying to sort through it. 

**No! We are better than that**

Instead what we are going to do is play each release ONCE, then decide what to do with it. The ones you like, feel free to do what is right and go and buy things, I do.

Here's how we do it

    $ mpv-once

    https://chrismckenzie.bandcamp.com/album/astrophilosophy

    Playing: chrismckenzie/astrophilosophy/chris mckenzie - Astrophilosophy-3196176877.mp3
    .. listen

    Exiting... (Quit)
    chrismckenzie/astrophilosophy >> 


"Oh great, a REPL". you say

Don't worry, it'll be easy.

Here we decide what to do with what we just heard. We can

  * r - replay it
  * pu - purge (move it /tmp and mark it as undesired)
  * s - skip the decision making
  * 1-5 - rate it from 1-5
  * q - exit

That wasn't painful, hopefully.

I'm going to decide to dump my own music, that slouch is awful.

    chrismckenzie/textures-i >> pu
    + base=/sd/mp3/label
    + mkdir -p /tmp/chrismckenzie/astrophilosophy
    + mv '/sd/mp3/label/chrismckenzie/astrophilosophy/chris mckenzie - Astrophilosophy-3196176877.mp3' '/sd/mp3/label/chrismckenzie/astrophilosophy/chris mckenzie - Instrumentals-2161707097.mp3' '/sd/mp3/label/chrismckenzie/astrophilosophy/chris mckenzie - Vocals-589691184.mp3' /sd/mp3/label/chrismckenzie/astrophilosophy/exit-code /tmp/chrismckenzie/astrophilosophy
    + touch /sd/mp3/label/chrismckenzie/astrophilosophy/no

And there we go. A placeholder file is put there so that when album-get comes through again, it won't try to grab it again.

After you exit this tool, the diligent students will notice a few dot files have been created:

    $ ls -1 .*
    .dl_history
    .listen_all
    .listen_done

Here's the one you want to look at (The other two are just for management/overhead)

### .listen_done - the list of releases you've gone through.

The format is 

    path __rating__ date

This is so you can do something like:

    $ awk ' { print $NF } ' .listen_done | sort | uniq -c

And see how many you go through every day. Kinda interesting. 

You can also do this:

    $ grep rating_5 .listen_done

And see all the stuff you gave a high rating to.

There's a tool included called rating-distrib.py that puts things into a histogram, like so:

![rating distribution](http://i.9ol.es/rating-distrib.png)

... there's a lot more ... I'll write later
