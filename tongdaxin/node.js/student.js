let student = { 
  name: "Baingan Guy", //String
  address: "Insta Memes", //String
  student: true, //Boolean
  number: undefined, //undefined
  regnumber: 007, //Number
};
// All datatypes together called object
// to access the object data
console.log(student.name);
console.log(student.regnumber);
console.log(typeof student);

function printPerson(name,age) {
  console.log('The person name is ' + name + 'and their age is ' + age);
}

printPerson("Ram" , 500);

function add(num1, num2) {
  return num1+2;   //returns sum of the two parameters.
}
let a = add(2,3);
console.log(a);


