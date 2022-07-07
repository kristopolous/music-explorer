var el, 
  search,
  ttl_dom,
  label = false,
  release = false,
  rel_link = document.createElement('a'),
  label_link = document.createElement('a'),
  qstr = window.location.hash.split('/')[1] || '',
  pl = [], 
  offset = parseInt(window.location.hash.slice(1) || localStorage['off'] || Math.round(Math.random()*1e8));

if(isNaN(offset)) {
  offset = 0;
}

function path_to_url(str) {
  return 'https://bandcamp.com/EmbeddedPlayer/size=large/bgcol=333333/linkcol=ffffff/transparent=true/track=' + str.match(/(\d*).mp3$/)[1];
}

function play_url(str) {
  let 
    l = str.split(/\//)[4],
    r = str.split(/\//)[5],
    src = path_to_url(str);

    label_link.innerHTML = l.replace(/-/g, ' ');
  r = r.replace(/-/g,' ');
  rel_link.innerHTML = r;
  document.querySelector('iframe').src = src;

  // this is the url to play.
  fetch(`url2mp3.php?path=${str}&u=${src}`)
    .then(response => response.text())
    .then(data => {
      el.src = data;
      el.play();
      [1, 5, 100].forEach( delta => {
        if(pl[offset + delta]) {
          // prefetch next
          fetch('url2mp3.php?u=' + path_to_url(pl[offset + delta]))
        }
      });
    });

}

function d(what, opts = {}) {
  if(opts.absolute) {
    offset = 0;
  } 

  offset += what;
  localStorage['off'] = offset;
  window.location.hash = [offset,qstr].join('/');
  getit(offset,opts);
  el.focus();
}

function getit(off,opts={}) {
  let _off = off % 1e6, ix;
  if(!opts.skip && pl[_off]) {
    return play_url(pl[_off]);
  }
  let url = `get_playlist_sql.php?off=${off}&q=${qstr}`
  // skip 
  //    +/- label
  //    +/- release
  //
  if(opts.skip) {
    url += `&skip=${opts.skip}`;
  }
 
  fetch(url)
    .then(response => response.json())
    .then(data => {
      _off = data.off;
      for(ix=0; ix < data.res.length; ix++){
        pl[_off + ix] = data.res[ix];
      }
      pl[_off + ix] = false;
      ttl_dom.innerHTML = data.ttl;
      
      window.location.hash = [data.off,qstr].join('/');
      if(_off !== offset) {
        offset = _off;
        window.location.hash = [offset,qstr].join('/');
      }

      play_url(pl[_off]);
    });
}

function dosearch(str) {
  pl = [];
  search.value = str;
  qstr = str.replace(/ /g, '.');
  d(0, {absolute:true});
}

window.onload = () => {
  el = document.querySelector('audio');
  search = document.querySelector('#search');
  ttl_dom = document.querySelector('#ttl');
  search.value = qstr;
  document.querySelector('#rel').appendChild(rel_link);
  document.querySelector('#label').appendChild(label_link);
  label_link.onclick = function() {
    dosearch(label_link.innerHTML);
  }
  rel_link.onclick = function() {
    dosearch(rel_link.innerHTML);
  }

  search.onkeydown = (e) => { 
    console.log(e);
    if([e.key, e.code].includes('Enter')) {
      dosearch(search.value);
    }
  }

  el.onended = () => {
    d(1);
    Notification.requestPermission().then(p => {
      if (p === "granted") {
        let s = decodeURIComponent(el.src).split('/').reverse();
        new Notification(s[1].replace(/-/g, ' ').toUpperCase(), {
          body: s[0].replace(/-(\d*).mp3$/,'')});
      }
    });
  }
  getit(offset);
}
