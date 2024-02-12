#!/usr/bin/env perl

use warnings;
use strict;

my @pal = (
           0x0000, 0x0001, 0x0102, 0x0202, 0x0112, 0x0122, 0x0223, 0x0224,
           0x0234, 0x0333, 0x0335, 0x0346, 0x0456, 0x0457, 0x0842, 0x0641,
          );


my (@paldiff_r, @paldiff_g, @paldiff_b);

for my $rgb (@pal) {
    my $r = $rgb >> 8;
    my $g = ($rgb >> 4) & 0x0f;
    my $b = ($rgb) & 0x0f;

    my $rdiff = (0xd - $r) / 18;
    my $gdiff = (0xd - $g) / 18;
    my $bdiff = (0xf - $b) / 18;

    push @paldiff_r, $rdiff;
    push @paldiff_g, $gdiff;
    push @paldiff_b, $bdiff;

}

my @pallist;

for my $mult (0..15) {
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

# Copy index 1 to 0 in the high palettes

for my $i (1..15) {
    $pallist[$i*16] = $pallist[$i*16+1];
}

while (@pallist) {
    print("\t.word ");
    my @x = splice(@pallist,0,16);
    print(join(",",@x));
    print("\n");
}
