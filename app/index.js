var path = require('path'),
  express = require('express'),
  app = express(),
  bodyParser = require('body-parser')

app.set('port', process.env.PORT_EX || 3000)
app.use(express.static(__dirname + '/public'))
app.use(bodyParser.json())
app.use(bodyParser.urlencoded({
  extended: true
}))

var Redis = require('ioredis'),
  cluster = new Redis.Cluster([{
      host: '172.17.0.10',
      port: 6379
    },
    {
      host: '172.17.0.8',
      port: 6379
    },
    {
      host: '172.17.0.3',
      port: 6379
    }
  ], {
    scaleReads: 'slave'
  }),
  key

// get all masters/slaves
masters = cluster.nodes('master')
// slaves = cluster.nodes('slave')
cluster.on('ready', function() {
  console.log('server ready')
})
for (var i = 0; i < 1000; i++) {
  cluster.set('foo' + i, 'bar' + i)
}

for (var i = 0; i < 1000; i++) {
  cluster.set('quux' + i, 'baz' + i)
}

cluster.on('error', function(err) {
  console.log("REDIS CONNECT error " + err);
  console.log('node error', err.lastNodeError);
});

function getKey(key) {
  return Promise.all(masters.map(function(node) {
      var success = node.get(key, function(err, res) {
        if (err) console.log(`Error: ${err}`)
        if (err.indexOf('MOVED') != -1) {
          return getKey(key)
        }
        success.key = res
      })
      if (success) {
        success.info = node.info()
      }
      return success
    }))
    .then(function(resp) {
      return resp
    })
    .catch(function(err) {
      return `oh no! Got error: ${err}`
    })
}

function getInfo(key) {
  Promise.all(masters.map(function(node) {
      return node.info()
    }))
    .then(function(resp) {
      console.log(`cluster config: ${JSON.stringify(resp, null, 2)}`)
    })
    .catch(function(err) {
      return `oh no! Got error: ${err}`
    })
}

var info = getKey('foo500')
console.log(`cluster config: ${JSON.stringify(info, null, 2)}`)

//API Routes
app.get('/', function(req, res) {
  res.type('text/html')
  res.sendFile(path.join(__dirname, '../public', 'index.html'))
});

// app.get('/key', function(req, res) {
//   var key = getKey(req.)
//   res.type('application/json');
//   res.json({});
// });

//404 catch-all handler (middleware)
app.use(function(req, res) {
  res.type('text/plain');
  res.status(404);
  res.send('404 - Not Found');
});

//500 error handler (middleware)
app.use(function(err, req, res, next) {
  res.status(500)
    .render('500');
});

app.listen(app.get('port'), function() {
  console.log('Express started on http://localhost:' +
    app.get('port') + '; press Ctrl-C to terminate.')
});
