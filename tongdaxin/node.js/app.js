var myModule = require('./module.js');

const hello = myModule.hello();
const sum = myModule.add(5,6);
const difference = myModule.subtract(10,4);
const product = myModule.multiply(3,7);
const quotient = myModule.divide(90,10);

console.log(hello);
console.log("Sum " + sum);
console.log("Difference " + difference);
console.log("Product " + product);
console.log("Quotient " + quotient);
