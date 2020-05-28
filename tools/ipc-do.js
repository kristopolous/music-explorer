#!/usr/bin/env nodejs

const net = require('net');
const client = net.createConnection('/tmp/mpvsocket')
const quitList = ['pause', 'playback-restart', 'unpause'];
var cb = false;
var command = process.argv[process.argv.length - 1];
var direction = ['back', 'prev'].includes(command) ? -1 : 1;

const commandMap = {
  pause: ['set_property', 'pause', true],
  play: ['set_property', 'pause', false],
  startover: ['set_property', 'time-pos', 0],

  time: ['get_property', 'time-pos'],
  playlist: ['get_property', 'playlist-pos'],
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

    send(['set_property', 'playlist-pos', newpos ]);
  }
  command = 'playlist';

} else if (['back', 'forward'].includes(command)) {

  cb = function(pos) {
    send(['set_property', 'time-pos', pos + (10 * direction) ]);
  }
  command = 'time';
}

if (!commandMap[command]) {
  console.log(Object.keys(commandMap).concat(['back', 'forward','pauseplay', 'prev', 'next']).sort());
  process.exit();
}

client.on('connect', () => send(commandMap[command]));

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

