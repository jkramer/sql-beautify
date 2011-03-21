#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use SQL::Beautify;

my $sql = new SQL::Beautify( spaces => 2, uc_keywords => 1, lc_names => 1 );
my $query;
my $beauty;

ok( $sql, 'got instance' );

while ( my $in = <DATA> ) {
    my $result   = eval $in;
    my $deformat = $result;
    $deformat =~ tr/\r\n\t / /s;
    $sql->query( uc($deformat) );
    is( $result, $sql->beautify, 'Test convert from upper case' );
    $sql->query( lc($deformat) );
    is( $result, $sql->beautify, 'Test convert from lower case' );
}

done_testing;

__DATA__
"SELECT\n  *\nFROM\n  foo,\n  bar,\n  baz\nWHERE\n  foo.id = bar.id\n  AND\n  bar.id = baz.id\n"
"SELECT\n  *\nFROM\n  foo,\n  bar,\n  baz\nWHERE\n  foo.id = bar.id\n  AND\n  bar.id = baz.id\n"
"SELECT\n  foo.id,\n  bar.name\nFROM\n  foo,\n  bar,\n  baz\nWHERE\n  foo.id = bar.id\n  AND\n  bar.id = baz.id\n  OR\n  bar.id != foo.id\n"
