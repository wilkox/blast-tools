#!/usr/bin/perl

#TODO
#cite bioperl tutorial
#requires Bio::Perl

use Bio::Graphics;
use Bio::SeqFeature::Generic;

#read in blast output
while (my $line = <STDIN>) {
  my @line = split(/\t/, $line);
  $feature{@line[0]}{@line[1]}{'start'} = @line[6];
  $feature{@line[0]}{@line[1]}{'end'} = @line[7];
  $feature{@line[0]}{@line[1]}{'id'} = @line[2];
  $min{@line[0]} = @line[6] unless $min{@line[0]} < @line[6] && $min{@line[0]};
  $min{@line[0]} = @line[7] unless $min{@line[0]} < @line[7] && $min{@line[0]};
  $max{@line[0]} = @line[6] unless $max{@line[0]} > @line[6] && $max{@line[0]};
  $max{@line[0]} = @line[7] unless $max{@line[0]} > @line[7] && $max{@line[0]};
}
 
foreach my $query (keys(%feature)) {
  print STDERR "\nDrawing query $query...";
  my $panel = Bio::Graphics::Panel->new(
    -length    => $max{$query} - $min{$query},
    -pad_left  => 100,
    -pad_right => 100
  );

  my $full_length = Bio::SeqFeature::Generic->new(
    -start => $min{$query},
    -end   => $max{$query},
  );
  $panel->add_track($full_length,
    -glyph   => 'arrow',
    -tick    => 2,
    -fgcolor => 'black',
    -double  => 1,
  );

  my $track = $panel->add_track(
    -glyph     => 'graded_segments',
    -label     => 1,
    -bgcolor   => 'blue',
    -min_score => 0,
    -max_score => 100,
    -description => sub {
                          my $feature = shift;
                          my $score   = $feature->score;
                          return "%id=$score";
                        }
  );
   
  foreach my $hit (keys(%{$feature{$query}})) {
    my $feature = Bio::SeqFeature::Generic->new(
      -display_name => $hit,
      -start        => $feature{$query}{$hit}{'start'},
      -end          => $feature{$query}{$hit}{'end'},
      -score        => $feature{$query}{$hit}{'id'},
    );
    $track->add_feature($feature);
  }
   
  $query =~ s/:/_/g;
  $query =~ s/\//_/g;
  die unless open(PNG, ">$query.png");
  print PNG $panel->png;
  close PNG;
}
