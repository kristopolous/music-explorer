#!/usr/bin/zsh
method1() {
  (
    for release in $(tail -50000 .listen_done| grep rating_5 | awk ' { print $1 } '); do
      for track in $release/*mp3([1]); do
        echo $track
        id3v2 -R "$track" 
      done
    done
  ) | grep TPE2 | sort | sed -E s'/TPE[12]:\s*//g' | uniq -c | sort -n | uniq
}

method2() {
  {
    for release in $(tail -50000 .listen_done| grep rating_5 | awk ' { print $1 } '); do
      echo $(basename $release/*mp3([1])) | cut -d '-' -f 1
    done
  } | sort | uniq -c | sort -n 
}

method2
