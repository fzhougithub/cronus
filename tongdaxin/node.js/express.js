var express = require('express');

const app = express();

app.get('/', function(req, res) {
    const { name,age } = req.query;
    res.send('Hellow ${name}! You are age ${age} years old!');
});

app.get('/name',  function(req, res) {
    res.send('Pradeep Welcome to the server');
});

app.listen(5000, function() { 
  console.log('Server listening on http://localhost:5000/');
});
