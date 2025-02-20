var express = require('express')
var bodyparser = require('body-parser')
const app=express()
app.use(bodyparser.json())

const users = [
  { id: 1, name: 'John', age: 25 },
  { id: 2, name: 'Alice', age: 30 },
  { id: 3, name: 'Bob', age: 28 }
];

app.get('/',  function(req, res) {
  res.send('Hellow Express!');
});

app.get('/name', function(req, res) {
    const { name, age } = req.query;
    res.send(`Hello ${name}! You are ${age} years old!`);
});

app.get('/users/:id', function(req, res) {
    const { id } = req.params;
    res.send(`Hello user ${id}!`);
});

app.get('/users/:id/:name', function(req, res) {
  const { id, name } = req.params;
  res.send(`User ${id}! and the name is ${name}!`);
});

app.post('/users', (req, res) => {
  const newUser = req.body;
  newUser.id = users.length + 1;
  users.push(newUser);
  res.status(201).json(users);
});

app.put('/users/:id', (req,res) => {
  const userId = parseInt(req.params.id); // converts parameter tye to Integer
  const {name} = req.body;
  const user = users.find((u) => u.id === userId);
  if (user) {
  // If user is found, send their details with 200 code
  user.name = name;
  res.status(200).send(`User name is ${user.name} and the age is ${user.age}`);
  } else {
  // If user is not found, send a 404 response
  res.status(404).send('User not found');
  }
});

app.delete('/users/:id', (req, res) => {
  const userId = parseInt(req.params.id);

  const userIndex = users.findIndex((user) => user.id === userId);

  if (userIndex !== -1) {
    const deletedItem = users.splice(userIndex, 1);
    res.json(deletedItem[0]);
  } else {
    res.status(404).json({ error: 'Item not found' });
  }
});


app.listen(5000, function() { 
  console.log('Server listening on http://localhost:5000/');
});
