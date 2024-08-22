sudo apt install sqlite3-pcre sqlite3 php php-sqlite3
todo

  add a 4th tab to the drop-down, "settings" that surfaces the hidden settings

## explore mode
  Replace the track/label buttons with something like this

  purge / 3 4 5 / skip 
        ^^ before these were all transitional functions,
        taking us to the next release. They were intentionally
        distinct during the design to make accidents hard.

        However in a thumbed touch screen interface mistakes
        are going to be common.

 So Probably something like this

 +      + +      +
     <        >      Current track selection interface
 +      + +      +
 P | 3 | 4 | 5 | S   Ranking as before, these now set toggle
 [  Next Release ]   
  Normally this is disabled unless one of the above "toggles"
  is actuated.
 
 Also instead of stopping, like the normal interface, this will
 cycle around the album until a decision is made.

---
notes:
    Currently a sqlite store is used to get playlists from.
    There's 2 ways of addressing this. 

        * Fold existing unmarked tracks into sqlite with 
          a special flag.

        * Create an alternative way to interface the system
          that maps closer to the existing flat file
          way.
          
    (2) is the most harmless because it's essentially just
    another adapter to the existing system. Essentially
    it has to either get down to the bash based way OR
    the bash based way has to move up to the SQLite way

    So the surfacing has to be done *somewhere* the real
    question is should it be done asynchronously or
    realtime.

    The main risk is probably data corruption since
    I'm introducing a new system with write privelege.

    I think something like

    $ mpv-lib record_listen (path) (rating)

    will eventually be needed. In fact all of this should
    be routed like that.

        unlistened

    Of course this means running shell through php, arguably
    stupid. We also have the resolvable issue of permissions

