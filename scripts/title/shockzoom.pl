#!/usr/bin/env perl

use warnings;
use strict;

my @incr_l;
my @incr_h;
my @posincr_l;
my @posincr_h;

for my $i (0..255) {
    my $incr = 1000/($i+1);
    $incr *= 9;
    if ($incr > 0x7fff) {
        $incr = 0x7fff;
    }
    push @incr_l, int($incr) & 0xff;
    push @incr_h, (int($incr) >> 8) & 0xff;
    push @posincr_l, (int($incr) >> 1) & 0xff;
    push @posincr_h, (int($incr) >> 9) & 0xff;
}

print("shockzoom_l:\n");

while (@incr_l) {
    print("\t.byte ");
    my @x = splice(@incr_l,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("shockzoom_h:\n");

while (@incr_h) {
    print("\t.byte ");
    my @x = splice(@incr_h,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("ypos_incr_l:\n");

while (@posincr_l) {
    print("\t.byte ");
    my @x = splice(@posincr_l,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("ypos_incr_h:\n");

while (@posincr_h) {
    print("\t.byte ");
    my @x = splice(@posincr_h,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}
