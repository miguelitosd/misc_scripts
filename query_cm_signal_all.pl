#!/usr/bin/perl -w
use strict;

my $lynx="/home/mmarion/bin/lynx_cm_signal";
my %signals = ();
my @channels = ();
my %report = (1 => "ONE", 2 => "TWO", 3 => "THREE", 4 => "FOUR", 5 => "FIVE", 6 => "SIX",
              7 => "SEVEN", 8 => "EIGHT", 9 => "NINE", 10 => "TEN", 11 => "ELEVEN", 
              12 => "TWELVE", 13 => "THIRTEEN", 14 => "FOURTEEN", 15 => "FIFTEEN", 16 => "SIXTEEN");
my @values = ();

my $channels_next=0;
my $in_signal=0;
my $loop=1;
open my $data, '-|', $lynx or die "Can't run $lynx command: $!\n";
#   1 Locked 256QAM 16 633.00 MHz 2.10 dBmV 38.61 dB 3 0
#   2 Locked 256QAM 1 543.00 MHz 1.30 dBmV 38.61 dB 59 0
while (($loop eq 1) && (defined(my $line = readline $data))) {
    if ($line =~ /Downstream Bonded Channels/) {
        $channels_next=1;
    } elsif ($channels_next eq 1) {
        if ( $line =~ /Upstream Bonded Channels/ ) {
            last;
        } elsif ( $line =~ /(\d+)\s+Locked.*dBmV\s+(\d+\.\d+)\s+dB\s+(\d+)\s+(\d+)/ ) {
            my $channel=$1;
            my $snr=$2;
            my $corr=$3;
            my $uncorr=$4;
            push @channels,$channel;
            push @values,$snr;
        }
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

#[snip]
#   DOCSIS Network Access Enabled Allowed
#
#   Downstream Bonded Channels
#   Channel Lock Status Modulation Channel ID Frequency Power SNR Corrected
#   Uncorrectables
#   1 Locked 256QAM 16 633.00 MHz 2.10 dBmV 38.61 dB 3 0
#   2 Locked 256QAM 1 543.00 MHz 1.30 dBmV 38.61 dB 59 0
#   3 Locked 256QAM 2 549.00 MHz 1.50 dBmV 38.61 dB 78 0
#   4 Locked 256QAM 3 555.00 MHz 1.50 dBmV 38.98 dB 83 0
#[snip]
#
#   Upstream Bonded Channels
#   Channel Lock Status US Channel Type Channel ID Symbol Rate Frequency
#   Power
#   1 Locked ATDMA 50 5120 kSym/s 23.30 MHz 43.50 dBmV
#   2 Locked TDMA 52 2560 kSym/s 37.00 MHz 44.75 dBmV
#   3 Locked ATDMA 51 5120 kSym/s 30.60 MHz 44.25 dBmV
#   4 Locked TDMA 49 2560 kSym/s 18.50 MHz 42.75 dBmV
#[snip]
