var 
  hash = window.location.hash.slice(1).split('/'),
  _track,
  _el, 
  _release = {
    label: hash[0] || '',
    title: hash[1] || ''
  },
  _qstr = hash[3] || '',
  _next = {},
  _loop = true,
  _DOM = {
    rel: document.createElement('a'),
    label: document.createElement('a')
  },
  path_to_url = (str) => 'https://bandcamp.com/EmbeddedPlayer/size=large/bgcol=333333/linkcol=ffffff/transparent=true/track=' + str.match(/(\d*).mp3$/)[1];

function play_url(track) {
  let src = path_to_url(track.path);
  document.querySelector('iframe').src = src;
  _DOM.label.innerHTML = _release.label.replace(/-/g, ' ');
  _DOM.rel.innerHTML = _release.title.replace(/-/g,' ');
  _DOM.track.innerHTML = `${track.id + 1}:${_release.trackList.length}<br/>${_release.number + 1}:${_release.count}`;

  window.location.hash = [_release.label, _release.title, track.id, _qstr].join('/');

  // this is the url to play.
  fetch(`url2mp3.php?path=${track.path}&u=${src}`)
    .then(response => response.text())
    .then(data => {
      _el.src = data;
      _el.play();
      _DOM.controls.className = '';
      document.title = _el.title = track.title.replace(/\-\d*.mp3/, '');

      Object.values(_next).forEach( track => fetch('url2mp3.php?u=' + path_to_url(track.path) ));

      let rel = _release.trackList, ttl = rel.length;
      _next['+track'] = rel[(      track.id + 1) % ttl];
      _next['-track'] = rel[(ttl + track.id - 1) % ttl];
      _track = track;
    });
}

function d(skip, orig) {
  if(!_DOM.controls.className) {
    let next = _next[skip];

    if (next) { 
      if( !_loop && (
            (skip == '+track'   && next.id === 0)
         || (skip == '-track'   && next.id >= _track.id)
         || (skip == '+release' && next.number == 0) 
         || (skip == '-release' && next.number >= _release.number)
        ) 
      ) {
        return d(skip[0] + (skip[1] === 't' ? 'release' : 'label'), orig || skip);
      }

      // makes sure it's really a track
      if(next.id) {
        return play_url(next);
      }
    } 

    _DOM.controls.className = 'disabled';
    fetch("get_playlist.php?" + [
        `q=${_qstr}`,
        `skip=${skip}`,
        `orig=${orig}`,
        `release=${_release.title}`,
        `label=${_release.label}`
      ].join('&'))
      .then(response => response.json())
      .then(data => {
        _release = data.release;
        delete data.release;
        _next = data;
        play_url(_release.trackList[_release.track_ix]);
      });
  }
}

function dosearch(str) {
  _DOM.search.value = str;
  _qstr = str.replace(/ /g, '.');
  _next = {};
  _release = {title:'',label:''};
  d("+track");
}

window.onload = () => {
  _el = document.querySelector('audio');

  ['search','track','controls'].forEach(what => _DOM[what] = document.querySelector(`#${what}`));
  ['rel','label'].forEach(what => {
    document.querySelector(`#${what}`).appendChild(_DOM[what]);
    _DOM[what].onclick = () => dosearch(_DOM[what].innerHTML);
  });

  _DOM.track.onclick = function() {
    _loop = !_loop;
    _DOM.track.className = (_loop ? 'loop' : '');
  }

  _DOM.search.value = _qstr;
  _DOM.search.onkeydown = (e) => { 
    if([e.key, e.code].includes('Enter')) {
      dosearch(_DOM.search.value);
    }
  }

  _el.onended = () => {
    d("+track");
    Notification.requestPermission().then(p => {
      if (p === "granted") {
        let s = decodeURIComponent(el.src).split('/').reverse();
        new Notification(s[1].replace(/-/g, ' ').toUpperCase(), {
          body: s[0].replace(/-(\d*).mp3$/,'')});
      }
    });
  }
  d(hash[2] || "+track");
  _loop = false;
}
