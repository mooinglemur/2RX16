#!/usr/bin/env perl

use warnings;
use strict;
use v5.16;

my @incr_l;
my @incr_h;
my @posincr_l;
my @posincr_h;
my @xpos_s;
my @xpos_l;
my @xpos_h;
my @ypos_s;
my @ypos_l;
my @ypos_h;

my $incr = 0x17ff;

for my $i (0..255) {

    if ($i > 20) { 
        $incr = 24000/($i-15);
    }

    if ($incr > 0x7fff) {
        $incr = 0x7fff;
    }
    push @incr_l, int($incr) & 0xff;
    push @incr_h, (int($incr) >> 8) & 0xff;
    push @posincr_l, (int($incr*3) >> 1) & 0xff;
    push @posincr_h, (int($incr*3) >> 9) & 0xff;

    my $xper = ($incr/512)*160;
    my $yper = (($incr/512)*3)*16;

    my $xdiff = 1048576+((128-$xper));
    my $ydiff = 1048576+((16-$yper));

    push @xpos_s, int($xdiff * 256) & 0xff;
    push @xpos_l, int($xdiff) & 0xff;
    push @xpos_h, (int($xdiff) >> 8) & 0x07;
    push @ypos_s, int($ydiff * 256) & 0xff;
    push @ypos_l, int($ydiff) & 0xff;
    push @ypos_h, (int($ydiff) >> 8) & 0x07;


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

print("xpos_s:\n");

while (@xpos_s) {
    print("\t.byte ");
    my @x = splice(@xpos_s,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("xpos_l:\n");

while (@xpos_l) {
    print("\t.byte ");
    my @x = splice(@xpos_l,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("xpos_h:\n");

while (@xpos_h) {
    print("\t.byte ");
    my @x = splice(@xpos_h,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("ypos_s:\n");

while (@ypos_s) {
    print("\t.byte ");
    my @x = splice(@ypos_s,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("ypos_l:\n");

while (@ypos_l) {
    print("\t.byte ");
    my @x = splice(@ypos_l,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}

print("ypos_h:\n");

while (@ypos_h) {
    print("\t.byte ");
    my @x = splice(@ypos_h,0,16);
    my @y = map { sprintf("\$%02x", $_) } @x;
    print(join(",",@y));
    print("\n");
}
