var 
  hash = window.location.hash.slice(1).split('/'),
  _el, 
  _release = {
    label: hash[0] || '',
    title: hash[1] || ''
  },
  _next = {},
  _track,
  _loop = true,
  _DOM = {
    rel: document.createElement('a'),
    label: document.createElement('a')
  },
  _qstr = hash[3] || '';

function path_to_url(str) {
  return 'https://bandcamp.com/EmbeddedPlayer/size=large/bgcol=333333/linkcol=ffffff/transparent=true/track=' + str.match(/(\d*).mp3$/)[1];
}

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
      document.title = _el.title = track.title.replace(/\-\d*.mp3/, '');
      _el.play();
      _DOM.controls.className = '';

      Object.values(_next).forEach( track => fetch('url2mp3.php?u=' + path_to_url(track.path) ));

      let rel = _release.trackList, ttl = rel.length;
      _next['+track'] = rel[(      track.id + 1) % ttl];
      _next['-track'] = rel[(ttl + track.id - 1) % ttl];
      _track = track;
    });
}

function d(skip) {
  if(_DOM.controls.className){
    return;
  }
  let next = _next[skip];

  if (next) { 
    if( !_loop && (
          (skip == '+track'   && next.id === 0)
       || (skip == '-track'   && next.id >= _track.id)
       || (skip == '+release' && next.number == 0) 
       || (skip == '-release' && next.number >= _release.number)
      ) 
    ) {
      return d(skip[0] + (skip[1] === 't' ? 'release' : 'label'));
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
      `release=${_release.title}`,
      `label=${_release.label}`
    ].join('&'))
    .then(response => response.json())
    .then(data => {
      _release = data.release;
      delete data.release;
      _next = data;
      play_url(_release.trackList[0]);
    });
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
  ['search','track','controls'].forEach(what => _DOM[what] = document.querySelector('#' + what));

  _DOM.search.value = _qstr;

  document.querySelector('#rel').appendChild(_DOM.rel);
  document.querySelector('#label').appendChild(_DOM.label);
  _DOM.track.onclick = function() {
    _loop = !_loop;
    _DOM.track.className = (_loop ? 'loop' : '');
  }

  _DOM.label.onclick = () => dosearch(_DOM.label.innerHTML);
  _DOM.rel.onclick = () => dosearch(_DOM.rel.innerHTML);

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
  d("+track");
  _loop = false;
}
