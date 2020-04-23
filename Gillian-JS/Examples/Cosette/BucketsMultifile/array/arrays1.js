var buckets = require('../../buckets');

var n1 = symb_number(n1); // 1
var n2 = symb_number(n2); // 8
var n3 = symb_number(n3); // 10
var n4 = symb_number(n4); // 42

Assume(not (n1 = n2));
Assume(not (n1 = n3));
Assume(not (n1 = n4));

Assume(not (n2 = n3));
Assume(not (n2 = n4));

Assume(not (n3 = n4));


var numberArray = [n1, n2, n2, n2, n3, n3];

var reset = function () {
  numberArray = [n1, n2, n2, n2, n3, n3];
}

// initial setup
reset();

// indexOf
var res2 = buckets.arrays.indexOf(numberArray, n2);
Assert(res2 = 1);
var res3 = buckets.arrays.indexOf(numberArray, n4);
Assert(res3 = -1);
