
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
