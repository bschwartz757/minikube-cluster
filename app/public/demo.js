$(document)
  .ready(() => {



    fetch('http://192.168.99.100:32163/')
      .then((response) => {
        return response.json();
      })
      .then((j) => {
        var key = j.key
        $('.configInfo')
          .html(`key: ${key}`)
      })
      .catch((err) => {
        console.log(err);
      });
  });
