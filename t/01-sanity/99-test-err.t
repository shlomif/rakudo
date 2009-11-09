use v6;
use Test;
plan *;

# This is to test errors in Test.pm usage.

eval_dies_ok 'todo( "reason", -1 )', "Can't todo() -1 tests";
eval_dies_ok 'todo( "reason", 1.2 )', "Can't todo fraction of a test";

eval_dies_ok 'skip( "reason", -1 )', "Can't skip -1 tests";
eval_dies_ok 'skip( "reason", 1.2 )', "Can't skip a fraction of a test";

eval_dies_ok 'skip_rest', "Can't skip the rest of a file with no plan";

done_testing;

# vim: ft=perl6
