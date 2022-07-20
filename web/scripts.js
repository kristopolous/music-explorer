var 
  hash = window.location.hash.slice(1).split('/'),
  _track,
  _el, 
  _my = {
    label: hash[0] || '',
    release: hash[1] || ''
  },
  _qstr = hash[3] || '',
  _next = {},
  _loop,
  _db = {},
  _tab = 'track',
  _if = 0;
  _DOM = {},
  path_to_url = (str) => 'https://bandcamp.com/EmbeddedPlayer/size=large/bgcol=333333/linkcol=ffffff/transparent=true/track=' + str.match(/(\d*).mp3$/)[1],
  remote = (append = []) => fetch("get_playlist.php?" + [ `q=${_qstr}`, `release=${_my.release}`, `label=${_my.label}`, ...append ].join('&')).then(response => response.json());

function lookup(play) {
  if (_db[play.path]) {
    return new Promise(r => r(_db[play.path]));
  } 
  return fetch(`url2mp3.php?path=${encodeURIComponent(play.path)}&u=${path_to_url(play.path)}`)
    .then(response => response.text())
    .then(data => {
      _db[play.path] = data;
      return data;
    });
}

function play_url(play) {
  let src = path_to_url(play.path);
  let fake = (_track && _track.path === play.path);
  if(!fake) {
    _if = !_if;
    _DOM[`if${+_if}`].src = src;
    _DOM[`if${+_if}`].className = 'in';
    _DOM[`if${+ !_if}`].className = 'out';
    setTimeout(() => {
      _DOM[`if${+ !_if}`].src = src;
    }, 1200);
  }
  ['release','label'].forEach(a => _DOM[a].innerHTML = _my[a].replace(/-/g, ' '))
  _DOM.track.innerHTML = `${play.id + 1}:${_my.trackList.length}<br/>${_my.number + 1}:${_my.count}`;

  window.location.hash = [_my.label, _my.release, play.id, _qstr].join('/');
  _my.track = play.track;

  let rel = _my.trackList, ttl = rel.length;
  _next['+track'] = rel[(      play.id + 1) % ttl];
  _next['-track'] = rel[(ttl + play.id - 1) % ttl];
  /// this is the fake detector
  _track = play;

  Object.values(_next).forEach(lookup);

  // this is the url to play.
  return fake? new Promise(r => r(true)): lookup(play).then(data => {
       let parts = data.split('/');
       parts[parts.length - 1] = encodeURIComponent(parts[parts.length - 1]);
      _el.src = parts.join('/') 
      _el.play();
      _DOM.controls.className = '';
      document.title = _el.title = play.track;
    });
}

function d(skip, orig) {
  console.log('http ----', skip, orig);
  if(!_DOM.controls.className) {
    let next = _next[skip];

    if (next) { 
      if( !_loop && (
            (skip == '+track'   && next.id === 0)
         || (skip == '-track'   && next.id >= _track.id)
         || (skip == '+release' && next.number == 0) 
         || (skip == '-release' && next.number >= _my.number)
        ) 
      ) {
        return d(skip[0] + (skip[1] === 't' ? 'release' : 'label'), orig || skip);
      }

      if('id' in next) {
        if(skip[1] === 't') {
          return play_url(next);
        } else if(!orig || skip === orig) {
          play_url(next);
        }
      }
    } 

    _DOM.controls.className = 'disabled';
    return remote([ `action=${skip}`, `orig=${orig}` ])
      .then(data => {
        _my = data.release;
        delete data.release;
        _next = data;
        return play_url(_my.trackList[_my.track_ix]);
      });
  }
}

function dosearch(str) {
  _qstr =  encodeURIComponent(str);
  _next = {};
  _my = {release:'',label:''};
  d("+track");
}

window.onload = () => {
  _el = document.querySelector('audio');

  ['if0','if1','label','release','top','list','nav','navcontrols','search','track','controls'].forEach(what => _DOM[what] = document.querySelector(`#${what}`));

  _DOM.track.onclick = function() {
    _loop = !_loop;
    _DOM.track.className = (_loop ? 'loop' : '');
  }

  _DOM.search.value = _qstr;

  let s;
  _DOM.search.onkeydown = (e) => { 
    window.clearTimeout(s);
    s = window.setTimeout(() =>  {
      _qstr = encodeURIComponent(_DOM.search.value);
      _DOM.navcontrols.onclick();
    }, 250);

    if([e.key, e.code].includes('Enter')) {
      dosearch(_DOM.search.value);
    }
  }

  _DOM.navcontrols.onclick = (e) => {
    if(e){
      let what = e.target;
      _tab = what.innerHTML;
      
      what.parentNode.childNodes.forEach(m => m.className = '');
      what.className = 'selected';
    }

    remote([ `action=${_tab}` ])
      .then(data => {
        _DOM.list.innerHTML = '';
        _DOM.list.append(...data.sort().map((e,ix) => {
            let l = document.createElement('li');
            l.innerHTML = e.track || e;
            l.ix = ix;
            l.obj = e;

            if(l.innerHTML === _my[_tab]){
              l.className = 'selected';
            }
            return l;
          })
        );
        if(_DOM.list.scrollTop === 0 && _DOM.list.querySelector('.selected')) {
          _DOM.list.scrollTo(0, _DOM.list.querySelector('.selected').offsetTop - 150);
        }
      });
  }

  _DOM.list.onclick = (e) => {
    let ix = 0;
    if(e.target.tagName == 'LI'){
      if(_tab === 'track') {
        ix = e.target.ix;
        _my = e.target.obj;
      } else {
        _my[_tab] = e.target.innerHTML;
        if(_tab === 'label'){
          _my.release = '';
        }
      }
      d(ix).then(_DOM.navcontrols.onclick);
    }
  }

  document.body.onclick = e => {
    e = e.target;
    while(e != document.body){
      if (e === _DOM.search) {
        _DOM.nav.style.display = 'block';
        _DOM.navcontrols.onclick();
      }
      if(e === _DOM.top) {
        return;
      }
      e = e.parentNode;
    }
    _DOM.nav.style.display = 'none';
  };

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
  d(hash[2] || 0).then(_DOM.navcontrols.onclick);
}
