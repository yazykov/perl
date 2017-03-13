#! usr/bin/env/perl -l

use strict;
use warnings;
use DDP;

$/ = "\n";

#system("$^X bin/analyze.pl access.log.bz2 >output.tmp 2>stderr.tmp");
#my $f = 'output.tmp';
#open(my $f, '<', 'output.tmp');
#$output_fh->close();

my $f = './access.log';
open F, $f or die "$!";
my %log = ();
my ($ip, $time, $request, $code, $compressed_bytes, $referrer, $user_agent, $coeff);

sub data_by_codes {
    my ($ip, $code, $compressed_bytes, $coeff) = @_;
    my $compressed_kilobytes = $compressed_bytes / 1024;
    $log{$ip}{compressed_data_by_code}{$code} += $compressed_kilobytes;
    if (200 == $code) {
        #$coeff = 1 if $coeff !~ /\d+(\.\d+)*/;
        $coeff = 1 if $coeff =~ /^-$/; #very probably it is ok
        $log{$ip}{uncompressed_data_200} += $compressed_kilobytes * $coeff;
    }

}

sub avg_time {
    my ($count, $count_per_minute) = @_;
    return sprintf ("%.2f", $count / $count_per_minute)
}

sub codes_formatter {
    my ($arg, $current_ip) = @_;
    my $x = $current_ip->{compressed_data_by_code}{$arg} || 0;
    $x = sprintf("%.0f", $x);
    return $x;
}

sub time_formatter {
    $_[0] =~ s/:\d{2} / /;
}


while (<F>) {
    chomp;
    my @patt =
    /(.*?)\s\[(.*?)\]\s"(.*)"\s(\d+)\s(\d+)\s"(.*?)"\s"(.*?)"\s"(.*?)"/;
    next if 8 != @patt;

    ($ip, $time, $request, $code, $compressed_bytes, $referrer, $user_agent, $coeff) = @patt;
    #next unless $ip && $time ;
    time_formatter ($time);

    for ('total', $ip) {
        ++$log{$_}{count};
        if (!exists $log{$_}{times}{$time}) {
            $log{$_}{times}{$time} = 1;
            ++$log{$_}{count_per_minute};
        }
        data_by_codes ($_, $code, $compressed_bytes, $coeff);
    }
}

for (keys %log) {
    my $current_ip = $log{$_};
    $current_ip->{avg_time} = avg_time ($current_ip->{count}, $current_ip->{count_per_minute});
    delete $current_ip->{times};
}

my @codes = sort {$a <=> $b} keys $log{total}{compressed_data_by_code};

$, = "\t";
my $header = join $,, qw/IP  count   avg data/, sort {$a <=> $b} keys $log{total}{compressed_data_by_code};
print $header;

my @top_10 = (sort {$log{$b}{count} <=> $log{$a}{count}} keys %log)[0..10];
for (@top_10) {
    my $current_ip = $log{$_};
    my $rounded_data_200 = int ($current_ip->{uncompressed_data_200});
    my $rounded_data_codes = join $,, map {int($current_ip->{compressed_data_by_code}{$_} || 0)} @codes;
    print ($_, $current_ip->{count}, $current_ip->{avg_time}, $rounded_data_200, $rounded_data_codes);
    #print $_;
    #p $log{$_};
    #<>;
}

close F;
