{
  switch (NR % 3) {
    case 2: title=$0; break
    case 1: file=$0; break
    case 0: 
      split($0, parts, ":")
      duration = parts[1] * 60 + parts[2]
      subs="./"
      /https?:/ ~ title { subs="" }

      print "#EXTINF:" duration "," title "\n" subs file "\n"
      break
  }
}
