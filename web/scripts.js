var 
  _el, 
  _release = {
    label: localStorage['_label'] || '',
    title: localStorage['_release'] || ''
  },
  _next = {},
  _track,
  _loop = true,
  _relDOM = document.createElement('a'),
  _labelDOM = document.createElement('a'),
  _searchDOM,
  _ttlDOM,
  _trackDOM,
  _qstr = window.location.hash.split('/')[1] || '';

const UP = {
  '-track': '-release',
  '+track': '+release', 
  '+release': '+label',
  '-release': '-label'
}

function path_to_url(str) {
  return 'https://bandcamp.com/EmbeddedPlayer/size=large/bgcol=333333/linkcol=ffffff/transparent=true/track=' + str.match(/(\d*).mp3$/)[1];
}

function play_url(track) {
  let src = path_to_url(track.path);
  document.querySelector('iframe').src = src;
  _labelDOM.innerHTML = _release.label.replace(/-/g, ' ');
  _relDOM.innerHTML = _release.title.replace(/-/g,' ');
  _trackDOM.innerHTML = `${track.id + 1}/${_release.trackList.length}`;

  localStorage['_label'] = _release.label;
  localStorage['_release'] = _release.title  

  window.location.hash = [track.id, _qstr].join('/');

  // this is the url to play.
  fetch(`url2mp3.php?path=${track.path}&u=${src}`)
    .then(response => response.text())
    .then(data => {
      _el.src = data;
      document.title = _el.title = track.title.replace(/\-\d*.mp3/, '');
      _el.play();

      Object.values(_next)
        .forEach( 
          track => fetch('url2mp3.php?u=' + path_to_url(track.path) )
        );

      let rel = _release.trackList, ttl = rel.length;
      _next['+track'] = rel[(      track.id + 1) % ttl];
      _next['-track'] = rel[(ttl + track.id - 1) % ttl];
      _track = track;
    });
}

function d(skip) {
  let next = _next[skip];

  if (next) { 
    if( !_loop && (
          (skip == '+track'   && next.id === 0)
       || (skip == '-track'   && next.id >= _track.id)
       || (skip == '+release' && next.number == 0) 
       || (skip == '-release' && next.number >= _release.number)
      ) 
    ) {
      return d(UP[skip]);
    }

    // makes sure it's really a track
    if(next.id) {
      return play_url(next);
    }
  } 

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
  _searchDOM.value = str;
  _qstr = str.replace(/ /g, '.');
  _release = {title:'',label:''};
  d("+track");
}

window.onload = () => {
  _el = document.querySelector('audio');
  _searchDOM = document.querySelector('#search');
  _ttlDOM = document.querySelector('#ttl');
  _trackDOM = document.querySelector('#track');
  _searchDOM.value = _qstr;

  document.querySelector('#rel').appendChild(_relDOM);
  document.querySelector('#label').appendChild(_labelDOM);
  _trackDOM.onclick = function() {
    _loop = !_loop;
    _trackDOM.className = (_loop ? 'loop' : '');
  }
  _labelDOM.onclick = function() {
    dosearch(_labelDOM.innerHTML);
  }
  _relDOM.onclick = function() {
    dosearch(_relDOM.innerHTML);
  }

  _searchDOM.onkeydown = (e) => { 
    if([e.key, e.code].includes('Enter')) {
      dosearch(_searchDOM.value);
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
