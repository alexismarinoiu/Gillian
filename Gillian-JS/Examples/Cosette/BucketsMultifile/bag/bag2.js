var buckets = require('../../buckets');

// init
var bag = new buckets.Bag();

// size
var n1 = symb_number(n1);
var n2 = symb_number(n2);

bag.add(n1);

var res = bag.count(n2);
Assert(((n1 = n2) and (res = 1)) or ((not (n1 = n2)) and (res = 0)));
