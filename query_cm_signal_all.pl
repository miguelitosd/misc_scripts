#!/usr/bin/perl -w
use strict;

my $lynx="/home/mmarion/bin/lynx_cm_signal";
my %signals = ();
my @channels = ();
my %report = (8 => "EIGHT", 2 => "TWO", 3 => "THREE", 4 => "FOUR", 5 => "FIVE", 6 => "SIX", 7 => "SEVEN", 1 => "ONE");
my @values = ();

my $channels_next=0;
my $in_signal=0;
my $loop=1;
open my $data, '-|', $lynx or die "Can't run $lynx command: $!\n";
while (($loop eq 1) && (defined(my $line = readline $data))) {
    if ($line =~ /Downstream Bonding Channel Value/) {
        $channels_next=1;
    } elsif ($channels_next eq 1) {
        my $parse = $line;
        $parse =~ s/.*Channel ID //;
        @channels = split(/\s+/,$parse);
        $channels_next=0;
    } elsif ($line =~ /Signal to Noise Ratio/) {
        $in_signal=1;
        my $p = $line;
        $p =~ s/.*oise Ratio //g;
        $p =~ s/\s+dB//g;
        @values = split(/\s+/,$p);
    } elsif ($in_signal eq 1) {
        # *sigh* line wraps if enough channels...
        $in_signal=0;
        my $p = $line;
        $p =~ s/^\s+//g;
        $p =~ s/\s+dB//g;
        my @vals=split(/\s+/,$p); 
        while (my $v = shift @vals) {
            push(@values,$v);
        }
        $loop=0;
    } elsif ($line =~ /Downstream Modulation/) {
        $loop=0;
    }
}
close $data;
my $i = 0;
print "current values: ";
while ($i <= $#channels) {
    my $ch = $channels[$i];
    if (defined($report{$ch})) {
        print "CHAN$report{$ch}:$values[$i] ";
    }
    $i++;
}
exit 0;
#                      Downstream Bonding Channel Value
#                       Channel ID 8  2  3  4  5  6  7
#      Frequency 591000000 Hz  627000000 Hz  621000000 Hz  615000000 Hz
#                  609000000 Hz  603000000 Hz  597000000 Hz
#    Signal to Noise Ratio 37 dB  28 dB  37 dB  37 dB  38 dB  38 dB  37 dB
#    Downstream Modulation QAM256  QAM256  QAM256  QAM256  QAM256  QAM256
