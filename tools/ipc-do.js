const net = require('net');
const client = net.createConnection('/tmp/mpvsocket')
const command = process.argv[process.argv.length - 1];

const commandMap = {
  pause: ['set_property', 'pause', true],
  play: ['set_property', 'pause', false]
}

const expectMap = {
  pause: 'pause',
  play: 'unpause'
};

var expect = false;

client.on('connect', (s) => {
  var towrite = {};
  console.log(command);

  towrite.command = commandMap[command];
  expect = expectMap[command];

  if(towrite.command) {
    var towrite = JSON.stringify(towrite);
    client.write(Buffer.from(towrite + "\n", 'utf-8'));
  }
});

client.on('data', (data) => {
  data.toString('utf8').split('\n').forEach(rowRaw => {
    if (rowRaw.length) {
      let row = JSON.parse(rowRaw);
      if(row.event === expect) {
        process.exit();
      }
      console.log(row);
    }
  });
});

client.on('close', (data) => {
  console.log(data);
});

