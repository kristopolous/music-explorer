var _el, 
  _label = localStorage['_label'] || '',
  _release = localStorage['_release'] || '',
  _next = {},
  _album = {},
  _trackId = 0,
  _trackComp = {},
  _relDOM = document.createElement('a'),
  _labelDOM = document.createElement('a'),
  _searchDOM,
  _ttlDOM,
  _trackDOM,
  _qstr = window.location.hash.split('/')[1] || '',
  _pl = [];

function path_to_url(str) {
  return 'https://bandcamp.com/EmbeddedPlayer/size=large/bgcol=333333/linkcol=ffffff/transparent=true/track=' + str.match(/(\d*).mp3$/)[1];
}

function play_url(track) {
  let src = path_to_url(track.path);
  document.querySelector('iframe').src = src;
  _labelDOM.innerHTML = track.label.replace(/-/g, ' ');
  _relDOM.innerHTML = track.release.replace(/-/g,' ');
  _trackDOM.innerHTML = `(${_trackId + 1}/${_album.length})`;

  localStorage['_label'] = _label = track.label;
  localStorage['_release'] = _release = track.release;

  window.location.hash = [track.id, _qstr].join('/');

  // this is the url to play.
  fetch(`url2mp3.php?path=${track.path}&u=${src}`)
    .then(response => response.text())
    .then(data => {
      _el.src = data;
      _el.play();

      Object.values(_next).forEach( 
        track => fetch('url2mp3.php?u=' + path_to_url(track.path)) 
      );
      _next = {};

      nextTrack();
    });
}

function nextTrack() {
  _trackComp = {
    '+track': (_trackId + 1) % _album.length,
    '-track': (_album.length + _trackId - 1) % _album.length
  };

  _next['+track'] = _album[_trackComp['+track']];
  _next['-track'] = _album[_trackComp['-track']];
}

function d(skip) {
  if(_next[skip] && _pl[_next[skip].id]){
    if(skip in _trackComp){
      _trackId = _trackComp[skip];
    }
    play_url(_pl[_next[skip].id]);
  } else {
    fetch("get_playlist.php?" + [
        `q=${_qstr}`,
        `skip=${skip}`,
        `release=${_release}`,
        `label=${_label}`
      ].join('&'))
      .then(response => response.json())
      .then(data => {
        _trackId = 0;
        _album = data.tracks;
        _next = {
          '+release': data['+release'],
          '+label': data['+label'],
        };
        nextTrack();

        [].concat(data.tracks,Object.values(_next))
          .forEach( track => _pl[track.id] = track );

        play_url(_pl[data.tracks[0].id]);
      });
  }
}

function dosearch(str) {
  _pl = [];
  _searchDOM.value = str;
  _qstr = str.replace(/ /g, '.');
  _label = '';
  _release = '';
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
  _labelDOM.onclick = function() {
    dosearch(_labelDOM.innerHTML);
  }
  _relDOM.onclick = function() {
    dosearch(_relDOM.innerHTML);
  }

  _searchDOM.onkeydown = (e) => { 
    console.log(e);
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
}
