#!/usr/bin/env perl

use warnings;
use strict;
use v5.16;

my @incr_l;
my @incr_h;
my @posincr_l;
my @posincr_h;
my @pos_s;
my @pos_l;
my @pos_h;

my $incr = 0x2000;

for my $i (0..255) {
    if ($i < 20) {
        $incr*=(0x400/0x2000)**(1/20); # go from 0x2000 to 0x400 in 20 steps
    } elsif ($i < 64) {
        $incr*=1.002;
    } elsif ($i < 128) {
        $incr*=1.003;
    } else {
        $incr*=1.015;
    }

    if ($incr > 0x7fff) {
        $incr = 0x7fff;
    }
    push @incr_l, int($incr) & 0xff;
    push @incr_h, (int($incr) >> 8) & 0xff;
    push @posincr_l, (int($incr) >> 1) & 0xff;
    push @posincr_h, (int($incr) >> 9) & 0xff;

    my $per = ($incr/512)*16;

    my $diff = 1048576+((32-$per));
    
    push @pos_s, int($diff * 256) & 0xff;
    push @pos_l, int($diff) & 0xff;
    push @pos_h, (int($diff) >> 8) & 0x07;


}

print("planetzoom_l:\n");

while (@incr_l) {
    print("\t.byte ");
    my @x = splice(@incr_l,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("planetzoom_h:\n");

while (@incr_h) {
    print("\t.byte ");
    my @x = splice(@incr_h,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("planet_ypos_incr_l:\n");

while (@posincr_l) {
    print("\t.byte ");
    my @x = splice(@posincr_l,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("planet_ypos_incr_h:\n");

while (@posincr_h) {
    print("\t.byte ");
    my @x = splice(@posincr_h,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("planet_pos_s:\n");

while (@pos_s) {
    print("\t.byte ");
    my @x = splice(@pos_s,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("planet_pos_l:\n");

while (@pos_l) {
    print("\t.byte ");
    my @x = splice(@pos_l,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("planet_pos_h:\n");

while (@pos_h) {
    print("\t.byte ");
    my @x = splice(@pos_h,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

