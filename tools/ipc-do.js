#!/usr/bin/env nodejs

const net = require('net');
const client = net.createConnection('/tmp/mpvonce/mpvsocket')
const quitList = ['quit', 'pause', 'playback-restart', 'unpause'];
var cb = false;
var command = process.argv[2];
var direction = ['back', 'prev'].includes(command) ? -1 : 1;

const commandMap = {
  pause: ['set_property', 'pause', true],
  play: ['set_property', 'pause', false],
  startover: ['set_property', 'time-pos', 0],
  quit: ['quit'],
  getpause: ['get_property', 'pause']
}

function send(list) {
  var towrite = JSON.stringify({command: list});
  client.write(Buffer.from(towrite + '\n', 'utf-8'));
}

if (command == 'pauseplay') {
  cb = function(state) {
    send(['set_property', 'pause', !state ]);
  }
  command = 'getpause';

} else if (['prev', 'next'].includes(command)) {
  cb = function(pos) {
    let newpos = pos + direction;
    if(newpos < 0) {
      process.exit();
    }
    send(['set_property', 'playlist-pos', newpos]);
  }
  command = 'playlist-pos';

} else if (['back', 'forward'].includes(command)) {
  cb = function(pos) {
    // if the user passed a number it to go backward or forward some
    // specific amount
    let amount = parseInt(process.argv[3], 10) || 10;
    send(['set_property', 'time-pos', pos + amount * direction]);
  }
  command = 'time-pos';
}

if (!command) {
  console.log(Object.keys(commandMap).concat(['back', 'forward', 'pauseplay', 'prev', 'next']).sort());
  process.exit();
}

client.on('connect', () => {
  if(commandMap[command]) {
    send(commandMap[command]);
  } else {
    send(['get_property', command]);
  }
});

client.on('data', (data) => {
  data.toString('utf8').trim().split('\n').forEach(rowRaw => {
    let row = JSON.parse(rowRaw);
    console.log(row);

    if (quitList.includes(row.event) || !cb) {
      process.exit();
    } 

    if ('data' in row) {
      cb(row.data);
    }
  });
});

