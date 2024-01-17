#!/usr/bin/env perl

use warnings;
use strict;

my @pal = (0x0000, 0x0001, 0x0101, 0x0102, 0x0202, 0x0111, 0x0112, 0x0222,
           0x0223, 0x0234, 0x0333, 0x0335, 0x0346, 0x0454, 0x0456, 0x0457,
           0x0000, 0x0111, 0x0222, 0x0333, 0x0444, 0x0555, 0x0666, 0x0777,
           0x0000, 0x0100, 0x0200, 0x0300, 0x0410, 0x0521, 0x0643, 0x0765, 
          );


my (@paldiff_r, @paldiff_g, @paldiff_b);

for my $rgb (@pal) {
    my $r = $rgb >> 8;
    my $g = ($rgb >> 4) & 0x0f;
    my $b = ($rgb) & 0x0f;

    my $rdiff = (0xd - $r) / 8;
    my $gdiff = (0xd - $g) / 8;
    my $bdiff = (0xd - $b) / 8;

    push @paldiff_r, $rdiff;
    push @paldiff_g, $gdiff;
    push @paldiff_b, $bdiff;

}

my @pallist;

for my $mult (0..7) {
    for my $i (0..$#pal) {
        my $rgb = $pal[$i];
        my $r = $rgb >> 8;
        my $g = ($rgb >> 4) & 0x0f;
        my $b = ($rgb) & 0x0f;

        $r += int(0.5 + $paldiff_r[$i] * $mult);
        $g += int(0.5 + $paldiff_g[$i] * $mult);
        $b += int(0.5 + $paldiff_b[$i] * $mult);

        push @pallist, sprintf("\$0%x%x%x",$r,$g,$b);
    }
}

while (@pallist) {
    print(".word ");
    my @x = splice(@pallist,0,16);
    print(join(",",@x));
    print("\n");
}