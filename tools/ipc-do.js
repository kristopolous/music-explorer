const net = require('net');
const client = net.createConnection('/tmp/mpvsocket')
var command = process.argv[process.argv.length - 1];

const commandMap = {
  pause: ['set_property', 'pause', true],
  play: ['set_property', 'pause', false],
  time: ['get_property', 'time-pos'],
  playlist: ['get_property', 'playlist-pos'],
  getpause: ['get_property', 'pause']
}

const quitList = [ 'pause', 'playback-restart', 'unpause' ];
var dataCb = false;
var direction = ['back','prev'].includes(command) ? -1 : 1;

function send(list) {
  var towrite = JSON.stringify({command: list});
  client.write(Buffer.from(towrite + "\n", 'utf-8'));
}

if (command == 'pauseplay') {
  dataCb = function(state) {
    send([ 'set_property', 'pause', !state ]);
  }
  command = 'getpause';
} else if (['prev','next'].includes(command)) {
  dataCb = function(pos) {
    let newpos = pos + direction;
    if(newpos < 0) {
      process.exit();
    }

    send([ 'set_property', 'playlist-pos', newpos ]);
  }
  command = 'playlist';
} else if (['back','forward'].includes(command)) {

  dataCb = function(pos) {
    send([ 'set_property', 'time-pos', pos + (10 * direction) ]);
  }
  command = 'time';
}

client.on('connect', () => {
  if(commandMap[command]) {
    send(commandMap[command]);
  }
});

client.on('data', (data) => {
  data.toString('utf8').trim().split('\n').forEach(rowRaw => {
    let row = JSON.parse(rowRaw);

    if(quitList.includes(row.event)) {
      process.exit();
    } 

    if('data' in row && dataCb) {
      dataCb(row.data);
    }
    console.log(row);
  });
});

