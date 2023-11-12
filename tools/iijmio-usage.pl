#!/usr/bin/perl -w

use strict;
use warnings;
use Carp;
use JSON;
use LWP::UserAgent;

my $endpoint = 'https://api.iijmio.jp/mobile/d/v2/log/packet/';
my $datadir  = '/run/iijmio/';

sub usage {
    print "usage: $0 [path/to/conf/file]\n";
    exit;
}

if (! -d $datadir) {
    carp "$datadir does not exist or is not directory.";
}

my $conf = shift @ARGV || '/etc/iijmio/usage.conf';
if (! -f $conf) {
    carp "$conf does not exist or is not regular file.";
    usage();
}

my ($developid, $accesstoken);
open my $fh, "<", $conf or croak "Error opening " . $conf;
while (my $line = <$fh>) {
    chomp $line;
    if ($line =~ /X-IIJmio-Developer=(.+)/) {
        $developid = $1;
    }
    if ($line =~ /X-IIJmio-Authorization=(.+)/) {
        $accesstoken = $1;
    }
}
unless (defined($developid) && defined($accesstoken)) {
    carp "$conf is not the correct conf file.";
    usage();
}


# 出力をバッファしない
$| = 1;

my $ua = LWP::UserAgent->new(
    timeout => 60,
);
$ua->default_header(
    "X-IIJmio-Developer"        => $developid,
    "X-IIJmio-Authorization"    => $accesstoken,
);

my $res = $ua->get($endpoint);
if ($res->is_success) {
    my $packetLogInfo = decode_json($res->content)->{packetLogInfo};
    foreach my $hddsvc (@{$packetLogInfo}) {
        if (exists $hddsvc->{hdoInfo}) {
            foreach my $hdoInfo (@{$hddsvc->{hdoInfo}}) {
                dumplog(
                    $hddsvc->{hddServiceCode},
                    $hdoInfo->{hdoServiceCode},
                    $hdoInfo->{packetLog},
                );
            }
            if (exists $hddsvc->{hduInfo}) {
                # unlike the sample of the API reference,
                # 'hduInfo' node does not exist in my case
                foreach my $hduInfo (@{$hddsvc->{hduInfo}}) {
                    dumplog(
                        $hddsvc->{hddServiceCode},
                        $hduInfo->{hduServiceCode},
                        $hduInfo->{packetLog},
                    );
                }
            }
        }
        if (exists $hddsvc->{hdxInfo}) {
            foreach my $hdxInfo (@{$hddsvc->{hdxInfo}}) {
                dumplog(
                    $hddsvc->{hddServiceCode},
                    $hdxInfo->{hdxServiceCode},
                    $hdxInfo->{packetLog},
                );
            }
        }
    }
}
else {
    print STDERR $res->status_line, ": ", $endpoint, "\n";
    print STDERR $res->content, "\n";
}

sub dumplog {
    my $hd1 = shift;
    my $hd2 = shift;
    my $packetlog = shift;

    unless (open my $fh, ">", "$datadir/usage.$hd1.$hd2") {
        carp "cannot open $datadir/usage.$hd1.$hd2";
        return;
    }
    else {
        foreach my $log (@{$packetlog}) {
            print $fh join(
                ",",
                $log->{date},
                $log->{withCoupon},
                $log->{withoutCoupon},
            ), "\n";
        }
    };
}
