break things down to input/output pair so whatever approach is used has known goals

api.py is the start of this

artists have releases
releases have labels
labels have releases
releases have artists


artists are in compilations

releases have credits


try every dimension and apply the same weight by default

distances are dimensionally relative

member distance:
  0 (a, b) - a & b were in band X
  1 (a, c) - a & b were in band X. b was in band Y with c.

label distance 
  (between labels)
    X% of artists on label Y released on label Z
    This is not commutative.
  (artists)
    X% of artists releases is on label Z
    Y% of label's releases is artist X

release distance:
  a & b have credits on the same release / total credits of a release


The objective is given a collection of artists suggest labels or other artists
based on these metrics


let's do a manual process.

  Let's start with this: https://www.discogs.com/release/9977808-Werner-Karloff-Hertz
    Label: https://www.discogs.com/label/750763-Young-And-Cold-Records
    Artist: https://www.discogs.com/artist/4388070-Werner-Karloff
      Group: https://www.discogs.com/artist/4364551-Neue-Strassen
      Group: https://www.discogs.com/artist/3964368-Rhythmus-23
      Label: https://www.discogs.com/label/55887-Hertz-Schrittmacher

  Appearances:
    
