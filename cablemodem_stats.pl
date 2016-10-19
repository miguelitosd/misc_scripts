#!/usr/bin/perl -w
 
use strict;
use 5.020;
use Cache::FileCache;
use Data::Dumper;
use Date::Format;
use File::Basename qw( basename );
use Getopt::Long qw( :config auto_help auto_version bundling no_ignore_case );
use IO::Socket;
use LWP::Simple;
my $scriptname = basename($0);
my $carbon_server = "127.0.0.1";
my $carbon_port = 2003;
my $cache_expiry = 55;     # Should set to just under how often you'll poll to 
                        # allow caching while testing but get live data when really polling
my $lynx_status = "SCRIPT TO lynx -dump http://$modem/cgi-bin/status or equiv";
my $lynx_swinfo = "SCRIPT TO lynx -dump http://modem/cgi-bin/swinfo or equiv";

GetOptions(
    'v|verbose'     =>  \my $verbose,
    'd|dryrun'      =>  \my $dryrun,
    'h|help'        =>  sub{ help() },
    's|server=s'    =>  \$carbon_server,
    'p|port=i'      =>  \$carbon_port,
);

my $sock = IO::Socket::INET->new(
    PeerAddr    => $carbon_server,
    PeerPort    => $carbon_port,
    Proto       => 'tcp',
) unless($dryrun);

if (!$dryrun) {
    die "Failed to connect o $carbon_server:$carbon_port: $!\n" unless ($sock->connected);
}

my $cm = load_cm_data();
my $now = time();
foreach my $type (sort keys %{$cm}) {
    next if (ref $cm->{$type} ne "HASH");
    foreach my $chan (sort keys %{$cm->{$type}}) {
        foreach my $key (sort keys %{$cm->{$type}->{$chan}}) {
            $sock->send("cablemodem.$type.$chan.$key $cm->{$type}->{$chan}->{$key} $now\n") unless($dryrun);
            verbose("\$sock->send\(\"cablemodem.$type.$chan.$key $cm->{$type}->{$chan}->{$key} $now\"\)");
        }
    }
}
if (defined($cm->{'uptime'})) {
    $sock->send("cablemodem.uptime $cm->{'uptime'} $now\n") unless($dryrun);
    verbose("\$sock->send\(\"cablemodem.uptime $cm->{'uptime'} $now\"\)");
}

$sock->shutdown(2) unless($dryrun);

# Handle the caching or actually get info from cablemodem.. mostly in here for
#  testing to avoid hitting modem more often.
sub load_cm_data {
    my $cache       = Cache::FileCache->new( { namespace => $scriptname } );
    my $key         = join ' ',$scriptname, 'web';
    my $data        = $cache->get( $key );
    if ( defined $data && ref $data eq 'HASH') {
        verbose("Cache hit");
        my $foo = $cache->get_object( $key );
        if (defined($foo->{'_Expires_At'})) {
            my $etime = $foo->{'_Expires_At'};
            my $left = $etime-time();
            verbose("Cache TTL = '$cache_expiry' seconds. $left seconds left");
        }
        return $data->{'stdout'};
    } 
    verbose("Cache miss, doing web query against cablemodem");
    verbose("Cache TTL = '$cache_expiry' seconds");
    my $starttime=time();
    verbose("Caching cm data");
    my $lcmd = $lynx_status;
    open my $lynx, '-|', $lcmd or die "Failure to rn $lcmd: $!\n";
    while (defined(my $line = readline($lynx))) {
        if (( $line =~ /.*Locked\s\d+QAM\s(\d+)\s+\d+\.\d+\sMHz\s+-\d+\.\d+\sdBmV\s+(\d+\.\d+)\s+dB\s+(\d+)\s+(\d+)/ ) or 
        ( $line =~ /.*Locked\s\d+QAM\s(\d+)\s+\d+\.\d+\sMHz\s+\d+\.\d+\sdBmV\s+(\d+\.\d+)\s+dB\s+(\d+)\s+(\d+)/ )) { 
            my $ch = $1; my $sig = $2; my $corr = $3; my $uncorr = $4;
            $data->{'stdout'}->{'down'}->{$ch}->{'sig'}=$sig;
            $data->{'stdout'}->{'down'}->{$ch}->{'corr'}=$corr;
            $data->{'stdout'}->{'down'}->{$ch}->{'uncorr'}=$uncorr;
        }
    }
    close $lynx;
    $lcmd = $lynx_swinfo;
    open $lynx, '-|', $lcmd or die "Failure to rn $lcmd: $!\n";
    while (defined(my $line = readline($lynx))) {
        if ($line =~ /Up Time (\d+)\s+d:\s+(\d+)\s+h:\s+(\d+)\s+m/) {
            my $uptime; 
            if (defined($1)) {
                $uptime=$1*86400;
            }
            if (defined($2)) {
                $uptime+=$2*3600;
            }
            if (defined($3)) {
                $uptime+=$3*60;
            }
            $data->{'stdout'}->{'uptime'}=$uptime;
        }
    }
    close $lynx;
    my $endtime=time();
    my $took = $endtime-$starttime;
    verbose("get took $took seconds, munging output");
    $cache->set( $key, $data, "$cache_expiry seconds" );
    return $data->{'stdout'};
}

sub verbose {
    return unless $verbose;
    say $_[0];
}

sub help {
    say "
Usage: $0 [--verbose|--dryrun]
    dryrun  : Don't send info to carbonDB
    verbose : Output verbose/debugging bits for testing
    ";
    exit;
}
