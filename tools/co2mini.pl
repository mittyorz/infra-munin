#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX;
use Fcntl;

# 出力をバッファしない
$| = 1;


my $device = "/dev/hidraw0";

# Result of printf("0x%08X\n", HIDIOCSFEATURE(9)); in C
my $HIDIOCSFEATURE_9 = 0xC0094806;

# Key retrieved from /dev/random, guaranteed to be random ;-)
my $key =	"\x86\x41\xc9\xa8\x7f\x41\x3c\xac";

sysopen(my $FH, $device, O_RDWR|O_APPEND) or die "Error opening " . $device;
	
# Send a FEATURE Set_Report with our key
ioctl($FH, $HIDIOCSFEATURE_9, "\x00".$key) or die "Error establishing connection to " . $device;

my %result;

#LOOP!
while (1) {

	my $len = sysread($FH, my $buf, 8);
	die "Could not read from device" if $len != 8;
            
	my @data = co2mini_decrypt($key, $buf);
	if($data[4] != 0xd or (($data[0] + $data[1] + $data[2]) & 0xff) != $data[3]) {
     		die "co2mini wrong data format received or checksum error";
	}


	if ( chr($data[0]) eq "B" ) {
		# 気温
		#printf ("  Temp = %s\n", ($data[1] << 8 | $data[2]) / 16.0-273.15);
		#printf("B");
		$result{"B"} = ($data[1] << 8 | $data[2]) / 16.0-273.15;
	} elsif ( chr($data[0]) eq "P" ) {
		# Co2濃度
		#printf ("  Co2 = %s ppm\n", $data[1] << 8 | $data[2]);
		#printf("P");
		$result{"P"} = $data[1] << 8 | $data[2];
	}

	# 気温とCO2濃度が揃ったら表示
	if ( $result{"B"} && $result{"P"} ) {
		my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
		#my $date = sprintf("%04d-%02d-%02d-%02d:%02d:%02d",
		#	$year + 1900, $mon + 1, $mday, $hour, $min, $sec);
		#printf("%s : Co2 = %s ppm, Temp = %.2f degC\n", $date, $result{"P"}, $result{"B"});
		#printf("Co2 = %s ppm, Temp = %.2f degC\n", $result{"P"}, $result{"B"});
		print "CO2 ", $result{"P"}, "\n";
		print "Temperature ", $result{"B"}, "\n";
		%result = ();
		exit();
	}

	#printf (".");
}




# Input: string key, string data
# Output: array of integers result
sub co2mini_decrypt {

  my @key = map { ord } split //, shift;
  my @data = map { ord } split //, shift;
  my @offset = (0x48,  0x74,  0x65,  0x6D,  0x70,  0x39,  0x39,  0x65);
  my @shuffle = (2, 4, 0, 7, 1, 6, 5, 3);
  
  my @phase1 = map { $data[$_] } @shuffle;
  my @phase2 = map { $phase1[$_] ^ $key[$_] } (0 .. 7);
  my @phase3 = map { ( ($phase2[$_] >> 3) | ($phase2[ ($_-1+8)%8 ] << 5) ) & 0xff; } (0 .. 7);
  my @ctmp = map { ( ($offset[$_] >> 4 ) | ($offset[$_] << 4 )) & 0xff; } ( 0 .. 7);
  my @result = map { (0x100 + $phase3[$_] - $ctmp[$_]) & 0xff; } (0 .. 7);
  
  return @result;
}

