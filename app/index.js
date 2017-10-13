var Redis = require('ioredis'),
  cluster = new Redis.Cluster([{
      host: '172.17.0.4',
      port: 6379
    },
    {
      host: '172.17.0.6',
      port: 6379
    }, {
      host: '172.17.0.9',
      port: 6379
    }
  ], {
    scaleReads: 'slave'
  }),
  key
// get all masters/slaves
// masters = cluster.nodes('master')
// slaves = cluster.nodes('slave')

cluster.on('error', function(err) {
  console.log("REDIS CONNECT error " + err);
  console.log('node error', err.lastNodeError);
});

// for (var i = 0; i < 1000; i++) {
//   cluster.set('foo' + i, 'bar' + i)
// }
//
// for (var i = 0; i < 1000; i++) {
//   cluster.set('quux' + i, 'baz' + i)
// }
console.log(Redis.Cluster.prototype.sscanStream)
stream = Redis.Cluster.prototype.sscanStream(
  /*{
    match: 'foo*[0-9]*',
    count: 100
  }*/
)

stream.on('data', function(resultKeys) {
  for (var i = 0; i < resultKeys.length; i++) {
    if (resultKeys[i] == 'foo500') {
      key = resultKeys[i]
    }
  }
})
stream.on('error', function(err) {
  console.log('stream error: ', err)
})
stream.on('end', function() {
  console.log('stream finished, found: ', key ? 'true' : 'false')
})

// can get a random key
// cluster.get('foo500', function(err, res) {
//   console.log('found key: ', res)
// })

// get a list of all keys - this should work with slaves
// Promise.all(masters.map(function(node) {
//     if (node.keys('*')) {
//       return node.keys('*')
//     }
//   }))
//   .then(function(resp) {
//     console.log('response from masters: ', resp)
//   })
//   .catch(function(p) {
//     return undefined
//   })

// for some reason this isn't returning any data... should, since we are using {scaleReads: 'slave'}
// Promise.all(slaves.map(function(node) {
//     if (node.keys('*')) {
//       return node.keys('*')
//     }
//   }))
//   .then(function(resp) {
//     console.log('response from slaves: ', resp)
//   })
//   .catch(function(p) {
//     return undefined
//   })


// const express = require('express')
// const app = express()
// const port = process.env.PORT_IN || 3000
//
// app.get('/', function(req, res) {
//   res.send('Hello World!')
// })
//
// app.listen(port, function() {
//   console.log(`Example app listening on port ${port}!`)
// })
