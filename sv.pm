
package Time::Duration::sv;
# Time-stamp: "2002-10-08 01:04:09 MDT"           POD is at the end.
$VERSION = '1.00';
require Exporter;
@ISA = ('Exporter');
@EXPORT = qw( later later_exact earlier earlier_exact
              ago ago_exact from_now from_now_exact
              duration duration_exact
              concise
            );
@EXPORT_OK = ('interval', @EXPORT);

use strict;
use constant DEBUG => 0;
use Time::Duration qw();
# ALL SUBS ARE PURE FUNCTIONS

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub concise ($) {
  my $string = $_[0];
  #print "in : $string\n";
  $string =~ s/,//g;
  $string =~ s/\boch\b//;
  $string =~ s/\b(dag|dagar|timme|timmar|minut|minuter|sekund|sekunder)\b/substr($1,0,1)/eg;
  $string =~s/år/å/g;
  my $save = '';
  if($string =~s/(för|om)//) {
	$save = $1;
  }
  $string =~ s/\s*(\d+)\s*/$1/g;

  return $save ? $save . " " . $string : $string;
}

sub later {
  interval(      $_[0], $_[1], '%s tidigare', '%s senare', 'just då'); }
sub later_exact {
  interval_exact($_[0], $_[1], '%s tidigare', '%s senare', 'just då'); }
sub earlier {
  interval(      $_[0], $_[1], '%s senare', '%s tidigare', 'just då'); }
sub earlier_exact {
  interval_exact($_[0], $_[1], '%s senare', '%s tidigare', 'just då'); }
sub ago {
  interval(      $_[0], $_[1], 'om %s', 'för %s sen', 'just nu'); }
sub ago_exact {
  interval_exact($_[0], $_[1], 'för %s sen', '%s ago', 'just nu'); }
sub from_now {
  interval(      $_[0], $_[1], 'för %s sen', 'om %s', 'just nu'); }
sub from_now_exact {
  interval_exact($_[0], $_[1], 'för %s sen', 'om %s', 'just nu'); }

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub duration_exact {
  my $span = $_[0];   # interval in seconds
  my $precision = int($_[1] || 0) || 2;  # precision (default: 2)
  return '0 sekunder' unless $span;
  _render('%s',
          _separate(abs $span));
}

sub duration {
    my $span = $_[0];   # interval in seconds
    my $precision = int($_[1] || 0) || 2;  # precision (default: 2)
    return '0 sekunder' unless $span;
  _render('%s',
          _approximate($precision,
                       _separate(abs $span)));
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub interval_exact {
  my $span = $_[0];                      # interval, in seconds
                                         # precision is ignored
  my $direction = ($span <= -1) ? $_[2]  # what a neg number gets
                : ($span >=  1) ? $_[3]  # what a pos number gets
                : return          $_[4]; # what zero gets
  _render($direction,
          _separate($span));
}

sub interval {
  my $span = $_[0];                      # interval, in seconds
  my $precision = int($_[1] || 0) || 2;  # precision (default: 2)
  my $direction = ($span <= -1) ? $_[2]  # what a neg number gets
                : ($span >=  1) ? $_[3]  # what a pos number gets
                : return          $_[4]; # what zero gets
  _render($direction,
          _approximate($precision,
                       _separate($span)));
}

#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#
#
# The actual figuring is below here

use constant MINUTE => 60;
use constant HOUR => 3600;
use constant DAY  => 24 * HOUR;
use constant YEAR => 365 * DAY;

sub _separate {
  # Breakdown of seconds into units, starting with the most significant
  
  my $remainder = abs $_[0]; # remainder
  my $this; # scratch
  my @wheel; # retval
  
  # Years:
  $this = int($remainder / (365 * 24 * 60 * 60));
  push @wheel, ['year', $this, 1_000_000_000];
  $remainder -= $this * (365 * 24 * 60 * 60);
    
  # Days:
  $this = int($remainder / (24 * 60 * 60));
  push @wheel, ['day', $this, 365];
  $remainder -= $this * (24 * 60 * 60);
    
  # Hours:
  $this = int($remainder / (60 * 60));
  push @wheel, ['hour', $this, 24];
  $remainder -= $this * (60 * 60);
  
  # Minutes:
  $this = int($remainder / 60);
  push @wheel, ['minute', $this, 60];
  $remainder -= $this * 60;
  
  push @wheel, ['second', int($remainder), 60];
  return @wheel;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub _approximate {
  # Now nudge the wheels into an acceptably (im)precise configuration
  my($precision, @wheel) = @_;

 Fix:
  {
    # Constraints for leaving this block:
    #  1) number of nonzero wheels must be <= $precision
    #  2) no wheels can be improperly expressed (like having "60" for mins)
  
    my $nonzero_count = 0;
    my $improperly_expressed;

    DEBUG and print join ' ', '#', (map "${$_}[1] ${$_}[0]",  @wheel), "\n";
    for(my $i = 0; $i < @wheel; $i++) {
      my $this = $wheel[$i];
      next if $this->[1] == 0; # Zeros require no attention.
      ++$nonzero_count;
      next if $i == 0; # the years wheel is never improper or over any limit; skip
      
      if($nonzero_count > $precision) {
        # This is one nonzero wheel too many!
        DEBUG and print '', $this->[0], " is one nonzero too many!\n";

        # Incr previous wheel if we're big enough:
        if($this->[1] >= ($this->[-1] / 2)) {
          DEBUG and printf "incrementing %s from %s to %s\n",
           $wheel[$i-1][0], $wheel[$i-1][1], 1 + $wheel[$i-1][1], ;
          ++$wheel[$i-1][1];
        }

        # Reset this and subsequent wheels to 0:
        for(my $j = $i; $j < @wheel; $j++) { $wheel[$j][1] = 0 }
        redo Fix; # Start over.
      } elsif($this->[1] >= $this->[-1]) {
        # It's an improperly expressed wheel.  (Like "60" on the mins wheel)
        $improperly_expressed = $i;
        DEBUG and print '', $this->[0], ' (', $this->[1], 
           ") is improper!\n";
      }
    }
    
    if(defined $improperly_expressed) {
      # Only fix the least-significant improperly expressed wheel (at a time).
      DEBUG and printf "incrementing %s from %s to %s\n",
       $wheel[$improperly_expressed-1][0], $wheel[$improperly_expressed-1][1], 
        1 + $wheel[$improperly_expressed-1][1], ;
      ++$wheel[ $improperly_expressed - 1][1];
      $wheel[ $improperly_expressed][1] = 0;
      # We never have a "150" in the minutes slot -- if it's improper,
      #  it's only by having been rounded up to the limit.
      redo Fix; # Start over.
    }
    
    # Otherwise there's not too many nonzero wheels, and there's no
    #  improperly expressed wheels, so fall thru...
  }

  return @wheel;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
my %env2sv = (
	second => ['sekund', 'sekunder'],
	minute => ['minut', 'minuter'],
	hour   => ['timme', 'timmar'],
	day    => ['dag','dagar'],
	year   => ['år','år'],

); 


sub _render {
  # Make it into English
	use Data::Dumper;

  my $direction = shift @_;
  my @wheel = map
  {
      (  $_->[1] == 0) ? ()  # zero wheels
	  : $_->[1] . ' ' . $env2sv{ $_->[0] }[ $_->[1] == 1 ? 0 : 1 ]
      }
  @_;

  return "just now" unless @wheel; # sanity
  my $result;
  if(@wheel == 1) {
      $result = $wheel[0];
  } elsif(@wheel == 2) {
      $result = "$wheel[0] och $wheel[1]";
  } else {
      $wheel[-1] = "och $wheel[-1]";
      $result = join q{, }, @wheel;
  }
  return sprintf($direction, $result);
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
1;

__END__

=head1 NAME

Time::Duration::sv - rounded or exact Swedish expression of durations

=head1 SYNOPSIS

Example use in a program that ends by noting its runtime:

  my $start_time = time();
  use Time::Duration::sv;
  
  # then things that take all that time, and then ends:
  print "Runtime ", duration(time() - $start_time), ".\n";

Example use in a program that reports age of a file:

  use Time::Duration::sv;
  my $file = 'that_file';
  my $age = $^T - (stat($file))[9];  # 9 = modtime
  print "$file was modified ", ago($age);

=head1 DESCRIPTION

This module provides functions for expressing durations in rounded or exact
terms.


=head1 SEE ALSO

L<Time::Duration|Time::Duration>, the English original, for a complete
manual.

=head1 COPYRIGHT AND DISCLAIMER

Copyright 2002, Arthur Bergman C<abergman@cpan.org>, all rights
reserved.  This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

Large parts of the code is Copyright 2002 Sean M. Burke. 

=head1 AUTHOR

Arthur Bergman, C<abergman@cpan.org>

=cut


